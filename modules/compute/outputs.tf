output "api_url" {
  description = "API Gateway invoke URL"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.greeting_logs.name
}

output "ecs_cluster_arn" {
  description = "ECS Cluster ARN"
  value       = aws_ecs_cluster.main.arn
}
