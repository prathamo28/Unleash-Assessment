terraform {
  required_version = ">= 1.4.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

# ----- Providers -----

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "eu_west_1"
  region = "eu-west-1"
}

# ----- Cognito (us-east-1 only) -----

module "cognito" {
  source = "./modules/cognito"

  providers = {
    aws = aws.us_east_1
  }

  user_email = var.user_email
}

# ----- Compute: us-east-1 -----

module "compute_us_east_1" {
  source = "./modules/compute"

  providers = {
    aws = aws.us_east_1
  }

  region                     = "us-east-1"
  cognito_user_pool_arn      = module.cognito.user_pool_arn
  cognito_user_pool_id       = module.cognito.user_pool_id
  cognito_user_pool_client_id = module.cognito.user_pool_client_id
  user_email                 = var.user_email
  github_repo                = var.github_repo
  sns_topic_arn              = var.sns_topic_arn
}

# ----- Compute: eu-west-1 -----

module "compute_eu_west_1" {
  source = "./modules/compute"

  providers = {
    aws = aws.eu_west_1
  }

  region                     = "eu-west-1"
  cognito_user_pool_arn      = module.cognito.user_pool_arn
  cognito_user_pool_id       = module.cognito.user_pool_id
  cognito_user_pool_client_id = module.cognito.user_pool_client_id
  user_email                 = var.user_email
  github_repo                = var.github_repo
  sns_topic_arn              = var.sns_topic_arn
}
