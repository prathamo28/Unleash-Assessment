output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = module.cognito.user_pool_id
}

output "cognito_client_id" {
  description = "Cognito App Client ID"
  value       = module.cognito.user_pool_client_id
}

output "api_url_us_east_1" {
  description = "API Gateway URL us-east-1"
  value       = module.compute_us_east_1.api_url
}

output "api_url_eu_west_1" {
  description = "API Gateway URL eu-west-1"
  value       = module.compute_eu_west_1.api_url
}
