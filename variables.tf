variable "user_email" {
  description = "Email address used for Cognito test user and SNS payloads"
  type        = string
  default     = "prathamesh.mokal@hotmail.com"
}

variable "github_repo" {
  description = "GitHub repo URL included in SNS payloads"
  type        = string
  default     = "https://github.com/prathamo28/aws-assessment"
}

variable "sns_topic_arn" {
  description = "Unleash live candidate verification SNS topic ARN"
  type        = string
  default     = "arn:aws:sns:us-east-1:637226132752:Candidate-Verification-Topic"
}
