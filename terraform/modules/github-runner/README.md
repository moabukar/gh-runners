# GitHub Runner Terraform Module

Terraform module for deploying self-hosted GitHub Actions runners on AWS EC2 with auto-scaling.

## Features

- **Ephemeral runners** - Instances self-terminate after job completion
- **Auto-scaling** - Scales to zero when idle, scales up on demand
- **Spot instances** - Cost-optimized with fallback to multiple instance types
- **Secure** - KMS encryption for SQS, IAM least-privilege, webhook signature validation
- **Observable** - CloudWatch logs, metrics, and alarms
- **High availability** - Multi-AZ deployment with SQS queue

## Usage

```hcl
module "github_runner" {
  source = "../../modules/github-runner"

  prefix     = "mycompany"
  github_org = "my-org"

  github_app = {
    id                 = "123456"
    installation_id    = "12345678"
    private_key_base64 = base64encode(file("private-key.pem"))
    webhook_secret     = "your-webhook-secret"
  }

  vpc_id     = "vpc-xxx"
  subnet_ids = ["subnet-aaa", "subnet-bbb"]

  instance_types        = ["m5.large", "m5a.large"]
  runners_maximum_count = 10
  spot_enabled          = true

  tags = {
    Environment = "prod"
    Team        = "platform"
  }
}
```

## Requirements

- Terraform >= 1.7
- AWS Provider ~> 5.0
- Python 3.11 (for Lambda functions)
- PyJWT, boto3, cryptography (installed via Lambda layer)

## Variables

See `variables.tf` for complete list. Key variables:

- `prefix` - Resource name prefix (required)
- `github_org` - GitHub organization name (required)
- `github_app` - GitHub App credentials (required, sensitive)
- `vpc_id` - VPC for runners (required)
- `subnet_ids` - Private subnets for runners (required)
- `instance_types` - EC2 instance types (default: `["m5.large", "m5a.large", "m5.xlarge"]`)
- `spot_enabled` - Use Spot instances (default: `true`)
- `runners_maximum_count` - Max concurrent runners (default: `10`)

## Outputs

- `webhook_endpoint` - GitHub webhook URL
- `runner_role_arn` - IAM role for runners
- `sqs_queue_url` - SQS queue URL
- `sqs_dlq_url` - Dead-letter queue URL

## Architecture

```
GitHub → API Gateway → Lambda (webhook) → SQS → Lambda (scale-up) → EC2
                                                      ↑
                                           EventBridge (scale-down)
```

## Security

- SQS queues encrypted with KMS
- Lambda functions use least-privilege IAM policies
- Webhook signature validation
- Instance metadata v2 enforced
- Secrets stored in AWS Secrets Manager

## Monitoring

CloudWatch alarms for:
- Lambda errors (>5 errors in 2 minutes)
- DLQ messages (any message in DLQ)

Optional: Set `alarm_sns_topic_arn` for notifications.

## Cost Optimization

- Spot instances (default)
- Ephemeral runners (scale to zero)
- Multi-instance type fallback
- Configurable log retention

## License

MIT
