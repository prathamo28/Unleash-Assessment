locals {
  rs = replace(var.region, "-", "")
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ecs_task_execution_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_dynamodb_table" "greeting_logs" {
  name         = "greeting-logs-${local.rs}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Project     = "unleash-live-assessment"
    Environment = "sandbox"
    Region      = var.region
  }
}

data "archive_file" "greeter" {
  type        = "zip"
  output_path = "${path.module}/lambda/greeter.zip"

  source {
    content  = templatefile("${path.module}/lambda/greeter.py.tpl", {})
    filename = "greeter.py"
  }
}

data "archive_file" "dispatcher" {
  type        = "zip"
  output_path = "${path.module}/lambda/dispatcher.zip"

  source {
    content  = file("${path.module}/lambda/dispatcher.py")
    filename = "dispatcher.py"
  }
}

resource "aws_iam_role" "lambda_greeter" {
  name               = "unleash-greeter-${local.rs}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "lambda_greeter" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:*"]
  }

  statement {
    actions   = ["dynamodb:PutItem"]
    resources = [aws_dynamodb_table.greeting_logs.arn]
  }

  statement {
    actions   = ["sns:Publish"]
    resources = [var.sns_topic_arn]
  }
}

resource "aws_iam_role_policy" "lambda_greeter" {
  role   = aws_iam_role.lambda_greeter.id
  policy = data.aws_iam_policy_document.lambda_greeter.json
}

resource "aws_iam_role" "lambda_dispatcher" {
  name               = "unleash-dispatcher-${local.rs}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "lambda_dispatcher" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:*"]
  }

  statement {
    actions   = ["ecs:RunTask"]
    resources = [aws_ecs_task_definition.sns_publisher.arn]
  }

  statement {
    actions   = ["iam:PassRole"]
    resources = [
      aws_iam_role.ecs_task_execution.arn,
      aws_iam_role.ecs_task.arn
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "lambda_dispatcher" {
  role   = aws_iam_role.lambda_dispatcher.id
  policy = data.aws_iam_policy_document.lambda_dispatcher.json
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "unleash-ecs-execution-${local.rs}"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task" {
  name               = "unleash-ecs-task-${local.rs}"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

data "aws_iam_policy_document" "ecs_task" {
  statement {
    actions   = ["sns:Publish"]
    resources = [var.sns_topic_arn]
  }
}

resource "aws_iam_role_policy" "ecs_task" {
  role   = aws_iam_role.ecs_task.id
  policy = data.aws_iam_policy_document.ecs_task.json
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/unleash-sns-${local.rs}"
  retention_in_days = 7
}

resource "aws_ecs_cluster" "main" {
  name = "unleash-cluster-${local.rs}"
}

resource "aws_ecs_task_definition" "sns_publisher" {
  family                   = "unleash-sns-publisher-${local.rs}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "sns-publisher"
      image     = "amazon/aws-cli:latest"
      essential = true
      # Default entrypoint is "aws", so we just pass CLI args
      command   = [
        "sns",
        "publish",
        "--region",
        "us-east-1",
        "--topic-arn",
        var.sns_topic_arn,
        "--message",
        jsonencode({
          email  = var.user_email
          source = "ECS"
          region = var.region
          repo   = var.github_repo
        })
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_lambda_function" "greeter" {
  function_name = "unleash-greeter-${local.rs}"
  role          = aws_iam_role.lambda_greeter.arn
  runtime       = "python3.12"
  handler       = "greeter.lambda_handler"
  filename      = data.archive_file.greeter.output_path

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.greeting_logs.name
      SNS_TOPIC_ARN  = var.sns_topic_arn
      USER_EMAIL     = var.user_email
      GITHUB_REPO    = var.github_repo
      EXEC_REGION    = var.region
    }
  }
}

resource "aws_lambda_function" "dispatcher" {
  function_name = "unleash-dispatcher-${local.rs}"
  role          = aws_iam_role.lambda_dispatcher.arn
  runtime       = "python3.12"
  handler       = "dispatcher.lambda_handler"
  filename      = data.archive_file.dispatcher.output_path

  environment {
    variables = {
      ECS_CLUSTER_ARN = aws_ecs_cluster.main.arn
      TASK_DEF_ARN    = aws_ecs_task_definition.sns_publisher.arn
      SUBNET_ID       = aws_subnet.public.id
      SG_ID           = aws_security_group.ecs_tasks.id
      EXEC_REGION     = var.region
    }
  }
}

