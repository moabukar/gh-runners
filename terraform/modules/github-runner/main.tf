################################################################################
# GitHub Actions Self-Hosted Runners - EC2 Auto-Scaling
################################################################################

locals {
  lambda_runtime = "python3.11"
  lambda_timeout = 60
  tags           = merge(var.tags, { Module = "github-runner" })
}

data "aws_ami" "runner" {
  most_recent = true
  owners      = var.ami_owners

  filter {
    name   = "name"
    values = var.ami_filter.name
  }

  filter {
    name   = "state"
    values = var.ami_filter.state
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}
