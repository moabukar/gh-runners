################################################################################
# Lambda - Scale Up
################################################################################

data "archive_file" "scale_up" {
  type        = "zip"
  output_path = "${path.module}/lambda/scale_up.zip"
  source {
    content  = file("${path.module}/lambda/scale_up.py")
    filename = "scale_up.py"
  }
}

resource "aws_lambda_function" "scale_up" {
  function_name                  = "${var.prefix}-runner-scale-up"
  role                           = aws_iam_role.lambda_scale_up.arn
  handler                        = "scale_up.handler"
  runtime                        = local.lambda_runtime
  timeout                        = local.lambda_timeout
  memory_size                    = 512
  filename                       = data.archive_file.scale_up.output_path
  source_code_hash               = data.archive_file.scale_up.output_base64sha256
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
      SECRET_ARN           = aws_secretsmanager_secret.github_app.arn
      GITHUB_ORG           = var.github_org
      RUNNER_GROUP         = var.runner_group
      RUNNER_LABELS        = join(",", var.runner_labels)
      SUBNET_IDS           = join(",", var.subnet_ids)
      SECURITY_GROUP_IDS   = join(",", [aws_security_group.runner.id])
      INSTANCE_PROFILE_ARN = aws_iam_instance_profile.runner.arn
      AMI_ID               = data.aws_ami.runner.id
      INSTANCE_TYPES       = join(",", var.instance_types)
      SPOT_ENABLED         = tostring(var.spot_enabled)
      RUNNERS_MAX          = tostring(var.runners_maximum_count)
      KEY_NAME             = var.key_name
      LOG_LEVEL            = var.log_level
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

resource "aws_lambda_event_source_mapping" "scale_up" {
  event_source_arn = aws_sqs_queue.webhook.arn
  function_name    = aws_lambda_function.scale_up.arn
  batch_size       = 1
}
