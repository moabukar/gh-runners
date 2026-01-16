################################################################################
# Secrets Manager
################################################################################

resource "aws_secretsmanager_secret" "github_app" {
  name        = "${var.prefix}-github-app"
  description = "GitHub App credentials for self-hosted runners"
  tags        = local.tags
}

resource "aws_secretsmanager_secret_version" "github_app" {
  secret_id = aws_secretsmanager_secret.github_app.id
  secret_string = jsonencode({
    app_id          = var.github_app.id
    installation_id = var.github_app.installation_id
    private_key     = var.github_app.private_key_base64
    webhook_secret  = var.github_app.webhook_secret
  })
}
