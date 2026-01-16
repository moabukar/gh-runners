terraform {
  required_version = ">= 1.7"

  required_providers {
    aws     = { source = "hashicorp/aws", version = "~> 5.0" }
    archive = { source = "hashicorp/archive", version = "~> 2.0" }
  }

  backend "s3" {
    bucket         = "CHANGEME-terraform-state"
    key            = "github-runners/prod/terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "eu-west-2"
  default_tags {
    tags = {
      Project     = "github-runners"
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

module "github_runner" {
  source     = "../../modules/github-runner"
  prefix     = var.prefix
  github_org = var.github_org

  github_app = {
    id                 = var.github_app_id
    installation_id    = var.github_app_installation_id
    private_key_base64 = var.github_app_private_key_base64
    webhook_secret     = var.github_webhook_secret
  }

  vpc_id                = var.vpc_id
  subnet_ids            = var.subnet_ids
  instance_types        = ["m5.large", "m5a.large", "m5.xlarge"]
  spot_enabled          = true
  runners_maximum_count = var.runners_maximum_count
  runner_labels         = ["self-hosted", "linux", "x64", var.prefix]

  ami_filter = { name = ["github-runner-*"], state = ["available"] }
  ami_owners = [data.aws_caller_identity.current.account_id]

  runner_additional_policy_arns = [
    aws_iam_policy.runner_ecr_push.arn,
    aws_iam_policy.runner_s3_artifacts.arn,
  ]
}

resource "aws_iam_policy" "runner_ecr_push" {
  name = "${var.prefix}-runner-ecr-push"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ecr:GetAuthorizationToken", "ecr:BatchCheckLayerAvailability", "ecr:PutImage", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_policy" "runner_s3_artifacts" {
  name = "${var.prefix}-runner-s3-artifacts"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket", "s3:DeleteObject"]
      Resource = ["arn:aws:s3:::${var.prefix}-build-artifacts", "arn:aws:s3:::${var.prefix}-build-artifacts/*"]
    }]
  })
}
