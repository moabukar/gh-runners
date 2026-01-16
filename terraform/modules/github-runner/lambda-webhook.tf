################################################################################
# Lambda - Webhook
################################################################################

data "archive_file" "webhook" {
  type        = "zip"
  output_path = "${path.module}/lambda/webhook.zip"
  source {
    content  = file("${path.module}/lambda/webhook.py")
    filename = "webhook.py"
  }
}

resource "aws_lambda_function" "webhook" {
  function_name                  = "${var.prefix}-runner-webhook"
  role                           = aws_iam_role.lambda_webhook.arn
  handler                        = "webhook.handler"
  runtime                        = local.lambda_runtime
  timeout                        = local.lambda_timeout
  memory_size                    = 256
  filename                       = data.archive_file.webhook.output_path
  source_code_hash               = data.archive_file.webhook.output_base64sha256
  layers                         = local.lambda_layers
  reserved_concurrent_executions = var.lambda_reserved_concurrency
  tracing_config {
    mode = var.enable_xray ? "Active" : "PassThrough"
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.webhook_dlq.arn
  }

  environment {
    variables = {
      SQS_QUEUE_URL = aws_sqs_queue.webhook.url
      SECRET_ARN    = aws_secretsmanager_secret.github_app.arn
      RUNNER_LABELS = join(",", var.runner_labels)
      LOG_LEVEL     = var.log_level
    }
  }

  dynamic "vpc_config" {
    for_each = var.lambda_vpc_config != null ? [var.lambda_vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  tags = local.tags
}
