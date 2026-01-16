config {
  module     = true
  force      = false
  disabled_by_default = false
}

plugin "aws" {
  enabled = true
  version = "0.31.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_deprecated_index" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_comment_syntax" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_module_pinned_source" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_standard_module_structure" {
  enabled = true
}

# AWS-specific rules
rule "aws_resource_missing_tags" {
  enabled = true
  tags    = ["Name", "Environment", "ManagedBy"]
}

rule "aws_iam_policy_document_gov_federation" {
  enabled = false
}

rule "aws_instance_previous_type" {
  enabled = false
}

rule "aws_s3_bucket_name" {
  enabled = false
}