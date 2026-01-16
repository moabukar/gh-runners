################################################################################
# Lambda - Scale Down
################################################################################

data "archive_file" "scale_down" {
  type        = "zip"
  output_path = "${path.module}/lambda/scale_down.zip"
  source {
    content  = file("${path.module}/lambda/scale_down.py")
    filename = "scale_down.py"
  }
}

resource "aws_lambda_function" "scale_down" {
  function_name                  = "${var.prefix}-runner-scale-down"
  role                           = aws_iam_role.lambda_scale_down.arn
  handler                        = "scale_down.handler"
  runtime                        = local.lambda_runtime
  timeout                        = local.lambda_timeout
  memory_size                    = 256
  filename                       = data.archive_file.scale_down.output_path
  source_code_hash               = data.archive_file.scale_down.output_base64sha256
  layers                         = local.lambda_layers
  reserved_concurrent_executions = var.lambda_reserved_concurrency
  tracing_config {
    mode = var.enable_xray ? "Active" : "PassThrough"
  }

  environment {
    variables = {
      SECRET_ARN            = aws_secretsmanager_secret.github_app.arn
      GITHUB_ORG            = var.github_org
      PREFIX                = var.prefix
      MIN_RUNNING_TIME_MINS = tostring(var.minimum_running_time_in_minutes)
      LOG_LEVEL             = var.log_level
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

resource "aws_cloudwatch_event_rule" "scale_down" {
  name                = "${var.prefix}-runner-scale-down"
  description         = "Trigger runner cleanup"
  schedule_expression = var.scale_down_schedule
  tags                = local.tags
}

resource "aws_cloudwatch_event_target" "scale_down" {
  rule      = aws_cloudwatch_event_rule.scale_down.name
  target_id = "ScaleDownLambda"
  arn       = aws_lambda_function.scale_down.arn
}

resource "aws_lambda_permission" "scale_down" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scale_down.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scale_down.arn
}
