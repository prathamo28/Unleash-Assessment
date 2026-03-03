resource "aws_cognito_user_pool" "main" {
  name = "unleash-live-user-pool"

  password_policy {
    minimum_length    = 8
    require_uppercase = true
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
  }

  auto_verified_attributes = ["email"]

  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true
  }

  tags = {
    Project     = "unleash-live-assessment"
    Environment = "sandbox"
  }
}

resource "aws_cognito_user_pool_client" "main" {
  name         = "unleash-live-client"
  user_pool_id = aws_cognito_user_pool.main.id

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]

  prevent_user_existence_errors = "ENABLED"
}

resource "aws_cognito_user" "test_user" {
  user_pool_id = aws_cognito_user_pool.main.id
  username     = var.user_email

  attributes = {
    email          = var.user_email
    email_verified = "true"
  }

  temporary_password   = "TempPass123!"
  message_action       = "SUPPRESS"
  force_alias_creation = false

  lifecycle {
    ignore_changes = [temporary_password]
  }
}
