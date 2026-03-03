locals {
  rs = replace(var.region, "-", "")
}

resource "aws_dynamodb_table" "greeting_logs" {
  name         = "GreetingLogs-${local.rs}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  attribute { name = "id", type = "S" }
  tags = { Project = "unleash-live-assessment" }
}

resource "aws_iam_role" "lambda_exec" {
  name = "unleash-lmb-${local.rs}"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "unleash-lmb-pol-${local.rs}"
  role = aws_iam_role.lambda_exec.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = "arn:aws:logs:*:*:*" },
      { Effect = "Allow", Action = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:Scan"], Resource = aws_dynamodb_table.greeting_logs.arn },
      { Effect = "Allow", Action = ["sns:Publish"], Resource = var.sns_topic_arn },
      { Effect = "Allow", Action = ["ecs:RunTask", "iam:PassRole"], Resource = "*" }
    ]
  })
}

data "archive_file" "greeter_zip" {
  type        = "zip"
  output_path = "/tmp/greeter-${local.rs}.zip"
  source {
    content  = templatefile("${path.module}/lambda/greeter.py.tpl", { sns_topic_arn = var.sns_topic_arn, user_email = var.user_email, github_repo = var.github_repo })
    filename = "handler.py"
  }
}

data "archive_file" "dispatcher_zip" {
  type        = "zip"
  output_path = "/tmp/dispatcher-${local.rs}.zip"
  source {
    content  = file("${path.module}/lambda/dispatcher.py")
    filename = "handler.py"
  }
}

resource "aws_lambda_function" "greeter" {
  function_name    = "unleash-greeter-${local.rs}"
  filename         = data.archive_file.greeter_zip.output_path
  source_code_hash = data.archive_file.greeter_zip.output_base64sha256
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.greeting_logs.name
      SNS_TOPIC_ARN  = var.sns_topic_arn
      USER_EMAIL     = var.user_email
      GITHUB_REPO    = var.github_repo
      EXEC_REGION    = var.region
    }
  }
  tags = { Project = "unleash-live-assessment" }
}

resource "aws_lambda_function" "dispatcher" {
  function_name    = "unleash-dispatcher-${local.rs}"
  filename         = data.archive_file.dispatcher_zip.output_path
  source_code_hash = data.archive_file.dispatcher_zip.output_base64sha256
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_exec.arn
  environment {
    variables = {
      ECS_CLUSTER_ARN = aws_ecs_cluster.main.arn
      TASK_DEF_ARN    = aws_ecs_task_definition.sns_publisher.arn
      SUBNET_ID       = aws_subnet.public.id
      SG_ID           = aws_security_group.ecs_tasks.id
      EXEC_REGION     = var.region
    }
  }
  tags = { Project = "unleash-live-assessment" }
}

# Appended ECS resources
resource "aws_ecs_cluster" "main" {
  name = "unleash-cluster-${local.rs}"
  tags = { Project = "unleash-live-assessment" }
}
resource "aws_iam_role" "ecs_task_exec" {
  name = "unleash-ecs-exec-${local.rs}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" } }]
  })
}
resource "aws_iam_role_policy_attachment" "ecs_exec_attach" {
  role       = aws_iam_role.ecs_task_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_role" "ecs_task_role" {
  name = "unleash-ecs-task-${local.rs}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" } }]
  })
}
resource "aws_iam_role_policy" "ecs_sns" {
  name   = "ecs-sns-${local.rs}"
  role   = aws_iam_role.ecs_task_role.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = ["sns:Publish"], Resource = var.sns_topic_arn }] })
}
resource "aws_ecs_task_definition" "sns_publisher" {
  family                   = "unleash-sns-pub-${local.rs}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_exec.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  container_definitions = jsonencode([{
    name      = "sns-publisher"
    image     = "amazon/aws-cli"
    essential = true
    command   = ["sns","publish","--topic-arn",var.sns_topic_arn,"--message","{\"email\":\"${var.user_email}\",\"source\":\"ECS\",\"region\":\"${var.region}\",\"repo\":\"${var.github_repo}\"}","--region","us-east-1"]
    logConfiguration = { logDriver = "awslogs", options = { "awslogs-group" = "/ecs/unleash-${var.region}", "awslogs-region" = var.region, "awslogs-stream-prefix" = "ecs", "awslogs-create-group" = "true" } }
  }])
  tags = { Project = "unleash-live-assessment" }
}
