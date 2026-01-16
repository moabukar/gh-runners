output "webhook_endpoint" {
  value       = module.github_runner.webhook_endpoint
  description = "Configure this URL in GitHub App webhook settings"
}

output "runner_role_arn" {
  value       = module.github_runner.runner_role_arn
  description = "Runner IAM role ARN"
}

output "sqs_dlq_url" {
  value       = module.github_runner.sqs_dlq_url
  description = "Dead-letter queue URL"
}
