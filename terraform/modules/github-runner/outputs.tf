output "webhook_endpoint" {
  value       = "${aws_apigatewayv2_api.webhook.api_endpoint}/webhook"
  description = "Webhook URL for GitHub App"
}

output "webhook_secret_arn" {
  value       = aws_secretsmanager_secret.github_app.arn
  description = "Secrets Manager ARN"
}

output "runner_role_arn" {
  value       = aws_iam_role.runner.arn
  description = "Runner IAM role ARN"
}

output "runner_role_name" {
  value       = aws_iam_role.runner.name
  description = "Runner IAM role name"
}

output "runner_security_group_id" {
  value       = aws_security_group.runner.id
  description = "Runner security group ID"
}

output "runner_instance_profile_arn" {
  value       = aws_iam_instance_profile.runner.arn
  description = "Runner instance profile ARN"
}

output "sqs_queue_url" {
  value       = aws_sqs_queue.webhook.url
  description = "SQS queue URL"
}

output "sqs_queue_arn" {
  value       = aws_sqs_queue.webhook.arn
  description = "SQS queue ARN"
}

output "sqs_dlq_url" {
  value       = aws_sqs_queue.webhook_dlq.url
  description = "Dead-letter queue URL"
}

output "lambda_layer_arn" {
  value       = length(local.lambda_layers) > 0 ? local.lambda_layers[0] : null
  description = "Lambda layer ARN for Python dependencies"
}

output "cloudwatch_dashboard_url" {
  value       = var.enable_dashboard && length(aws_cloudwatch_dashboard.runners) > 0 ? "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.runners[0].dashboard_name}" : null
  description = "URL to CloudWatch dashboard"
}
