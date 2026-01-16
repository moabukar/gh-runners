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

## Repository Structure

```
gh-runners/
├── terraform/
│   ├── modules/github-runner/    # Reusable module
│   │   ├── main.tf               # Core resources
│   │   ├── variables.tf          # Input variables
│   │   ├── outputs.tf            # Outputs
│   │   └── lambda/               # Lambda function code
│   └── environments/
│       └── prod/                 # Production config
├── packer/                       # Custom AMI definition
│   ├── github-runner.pkr.hcl
│   └── scripts/
├── docs/                         # Documentation
└── .github/workflows/            # CI/CD pipelines
```

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
