# Unleash live - AWS DevOps Engineer Assessment

Candidate: Prathamesh Mokal
Repo: https://github.com/prathamo28/aws-assessment

## Architecture

- Cognito User Pool in us-east-1 (centralised auth)
- Identical compute stack in us-east-1 AND eu-west-1:
  - HTTP API Gateway with Cognito JWT authorizer
  - Lambda Greeter (/greet) - writes to DynamoDB, publishes to SNS
  - Lambda Dispatcher (/dispatch) - triggers ECS Fargate RunTask
  - DynamoDB table (GreetingLogs)
  - ECS Fargate cluster (public subnet, no NAT Gateway)

## Prerequisites

- Terraform >= 1.5.0
- AWS CLI v2 + credentials configured
- Python 3.10+ with boto3

## Deploy

```bash
terraform init
terraform plan  -var="user_email=prathamesh.mokal@hotmail.com"
terraform apply -var="user_email=prathamesh.mokal@hotmail.com"
```

## Set Cognito Password

```bash
aws cognito-idp admin-set-user-password \
  --user-pool-id $(terraform output -raw cognito_user_pool_id) \
  --username prathamesh.mokal@hotmail.com \
  --password "YourPassword123!" \
  --permanent --region us-east-1
```

## Run Tests

```bash
export COGNITO_USER_POOL_ID=$(terraform output -raw cognito_user_pool_id)
export COGNITO_CLIENT_ID=$(terraform output -raw cognito_client_id)
export API_URL_US_EAST_1=$(terraform output -raw api_url_us_east_1)
export API_URL_EU_WEST_1=$(terraform output -raw api_url_eu_west_1)
export COGNITO_PASSWORD="YourPassword123!"
python scripts/test.py
```

The script authenticates, concurrently hits /greet and /dispatch in both regions,
asserts region in response body, and reports latency comparison.

## Teardown

Run immediately after SNS payloads are triggered:

```bash
terraform destroy -var="user_email=prathamesh.mokal@hotmail.com"
```

## Multi-Region Provider Design

Provider aliasing in main.tf creates two AWS providers (us-east-1, eu-west-1).
The compute module is instantiated twice, once per provider alias.
This ensures identical infrastructure with zero code duplication.

## CI/CD Pipeline

Stages: Lint/Validate -> Security Scan (tfsec) -> Plan (on PR) -> Apply (on merge) -> Test

GitHub Secrets needed: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, USER_EMAIL, COGNITO_TEST_PASSWORD
