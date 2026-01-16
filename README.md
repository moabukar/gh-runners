# GitHub Runners

Self-hosted GitHub Actions runners on EC2 with auto-scaling. Webhook-driven, ephemeral, scales to zero.

## Quick Start

```bash
# 1. Create GitHub App (see docs/SETUP.md)

# 2. Build AMI
cd packer
packer init github-runner.pkr.hcl
packer build github-runner.pkr.hcl

# 3. Deploy infrastructure
cd terraform/environments/prod
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform apply

# 4. Configure webhook URL in GitHub App settings (from terraform output)
```

## Architecture

```
GitHub webhook → API Gateway → Lambda → SQS → Lambda → EC2 (ephemeral)
                                                          ↓
                                              Self-terminates after job
```

- **Webhook Lambda**: Validates signature, filters `workflow_job.queued` events
- **Scale-up Lambda**: Generates JIT runner token, launches EC2 instance
- **Scale-down Lambda**: Terminates orphaned/stuck instances (scheduled)
- **Runners**: Spot instances, self-terminate after job completion

## Documentation

| Document | Audience |
|----------|----------|
| [docs/SETUP.md](docs/SETUP.md) | DevOps – Initial setup and deployment |
| [docs/USAGE.md](docs/USAGE.md) | Developers – Using runners in workflows |
| [docs/OPERATIONS.md](docs/OPERATIONS.md) | DevOps – Monitoring, troubleshooting, maintenance |

## Requirements

- AWS account with appropriate permissions
- GitHub organisation with admin access
- Terraform >= 1.7
- Packer >= 1.10 (for AMI builds)

## Cost Estimate

With Spot instances (default):
- 8 runners × m5.large × 8 hours/day × 22 days = ~£50-80/month
- Scale to zero when idle = £0 outside working hours
- NAT Gateway egress is the main fixed cost

## Development

### Pre-commit Hooks

Install pre-commit hooks for code quality checks:

```bash
# Install pre-commit
pip install pre-commit

# Install hooks
pre-commit install

# Run hooks manually
pre-commit run --all-files
```

Hooks include:
- Terraform formatting and validation
- Python code formatting (Black, isort, flake8)
- YAML/JSON validation
- Security scanning (tfsec, checkov)
- Linting (tflint)

### Make Targets

```bash
make help              # Show all available targets
make terraform-fmt     # Format Terraform files
make terraform-validate # Validate Terraform config
make build-layer       # Build Lambda layer
make clean             # Clean temporary files
```

### Lambda Layer Setup

The Lambda functions require PyJWT for GitHub API authentication. Build the layer:

```bash
# Build the layer
./build-lambda-layer.sh

# Or using make
make build-layer

# In your terraform.tfvars or environment, set:
# lambda_layer_zip_path = "./lambda-layer.zip"
```

Alternatively, use an existing layer ARN:
```hcl
lambda_layer_arn = "arn:aws:lambda:region:account:layer:name:version"
```

## Recent Improvements

- ✅ Lambda layer support for PyJWT dependencies
- ✅ Custom CloudWatch metrics for runner activity
- ✅ GitHub API retry logic with rate limiting
- ✅ CloudWatch dashboard for monitoring
- ✅ Lambda reserved concurrency configuration
- ✅ Enhanced error handling and logging
