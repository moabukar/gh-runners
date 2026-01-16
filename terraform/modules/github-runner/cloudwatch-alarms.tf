################################################################################
# CloudWatch Alarms
################################################################################

resource "aws_cloudwatch_metric_alarm" "lambda_webhook_errors" {
  alarm_name          = "${var.prefix}-runner-webhook-errors"
  alarm_description   = "Alert on Lambda webhook errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_actions       = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    FunctionName = aws_lambda_function.webhook.function_name
  }

  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_scale_up_errors" {
  alarm_name          = "${var.prefix}-runner-scale-up-errors"
  alarm_description   = "Alert on Lambda scale-up errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_actions       = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    FunctionName = aws_lambda_function.scale_up.function_name
  }

  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "sqs_dlq_messages" {
  alarm_name          = "${var.prefix}-runner-sqs-dlq-messages"
  alarm_description   = "Alert when messages arrive in DLQ"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_actions       = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []

  dimensions = {
    QueueName = aws_sqs_queue.webhook_dlq.name
  }

  tags = local.tags
}
