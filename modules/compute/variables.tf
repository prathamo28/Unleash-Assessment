variable "region" {
  description = "AWS region for this compute stack"
  type        = string
}

variable "cognito_user_pool_arn" {
  description = "ARN of the Cognito User Pool in us-east-1"
  type        = string
}

variable "cognito_user_pool_id" {
  description = "ID of the Cognito User Pool in us-east-1"
  type        = string
}

variable "user_email" {
  description = "User email for SNS payloads"
  type        = string
}

variable "github_repo" {
  description = "GitHub repo URL for SNS payloads"
  type        = string
}

variable "sns_topic_arn" {
  description = "Unleash live candidate verification SNS topic ARN"
  type        = string
}
