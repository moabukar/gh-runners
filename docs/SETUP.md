# Setup Guide

## Prerequisites

- AWS account with admin access
- GitHub organisation admin access
- Terraform >= 1.7
- Packer >= 1.10

## Step 1: Create GitHub App

1. Go to `https://github.com/organizations/{ORG}/settings/apps/new`

2. Configure:
   - **Name**: `{company}-runners`
   - **Webhook URL**: Leave blank (set after deploy)
   - **Webhook secret**: Generate with `openssl rand -hex 32`

3. Permissions:
   - Repository: Actions (Read), Administration (Read & Write), Checks (Read), Metadata (Read)
   - Organisation: Self-hosted runners (Read & Write)

4. Events: Workflow job ✓

5. After creation:
   - Note **App ID**
   - Generate **Private Key**
   - Install on organisation
   - Note **Installation ID**

## Step 2: Build AMI

```bash
cd packer
packer init github-runner.pkr.hcl
packer build github-runner.pkr.hcl
```

## Step 3: Deploy

```bash
cd terraform/environments/prod
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars

export TF_VAR_github_app_id="123456"
export TF_VAR_github_app_installation_id="12345678"
export TF_VAR_github_app_private_key_base64="$(base64 -w 0 < app.pem)"
export TF_VAR_github_webhook_secret="your-secret"

terraform init
terraform apply
```

## Step 4: Configure Webhook

1. Get URL: `terraform output webhook_endpoint`
2. Update GitHub App webhook settings with this URL
3. Activate webhook

## Step 5: Test

```yaml
# .github/workflows/test.yaml
name: Test Runner
on: workflow_dispatch
jobs:
  test:
    runs-on: [self-hosted, linux, x64]
    steps:
      - run: echo "Hello from $(hostname)"
```
