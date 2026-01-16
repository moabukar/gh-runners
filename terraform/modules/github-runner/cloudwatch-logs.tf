################################################################################
# CloudWatch Log Groups
################################################################################

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.prefix}-runner-webhook"
  retention_in_days = var.log_retention_days
  tags              = local.tags
}

resource "aws_cloudwatch_log_group" "lambda_webhook" {
  name              = "/aws/lambda/${var.prefix}-runner-webhook"
  retention_in_days = var.log_retention_days
  tags              = local.tags
}

resource "aws_cloudwatch_log_group" "lambda_scale_up" {
  name              = "/aws/lambda/${var.prefix}-runner-scale-up"
  retention_in_days = var.log_retention_days
  tags              = local.tags
}

resource "aws_cloudwatch_log_group" "lambda_scale_down" {
  name              = "/aws/lambda/${var.prefix}-runner-scale-down"
  retention_in_days = var.log_retention_days
  tags              = local.tags
}
