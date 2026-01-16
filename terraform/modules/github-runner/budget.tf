################################################################################
# AWS Budgets for Cost Monitoring
################################################################################

resource "aws_budgets_budget" "runner" {
  count = var.enable_budget ? 1 : 0

  name              = "${var.prefix}-runner-budget"
  budget_type       = "COST"
  limit_amount      = tostring(var.budget_limit_amount)
  limit_unit        = var.budget_limit_unit
  time_period_start = var.budget_time_period_start
  time_unit         = var.budget_time_unit

  cost_filters = {
    TagKeyValue = [
      "user:ManagedBy$terraform",
      "user:Module$github-runner"
    ]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = var.budget_threshold_percent
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_notification_emails
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = var.budget_forecasted_threshold_percent
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.budget_notification_emails
  }

  dynamic "notification" {
    for_each = var.budget_sns_topic_arn != "" ? [1] : []
    content {
      comparison_operator       = "GREATER_THAN"
      threshold                 = var.budget_threshold_percent
      threshold_type            = "PERCENTAGE"
      notification_type         = "ACTUAL"
      subscriber_sns_topic_arns = [var.budget_sns_topic_arn]
    }
  }

  tags = local.tags
}

################################################################################
# Cost Anomaly Detection
################################################################################

resource "aws_ce_anomaly_detector" "runner" {
  count = var.enable_cost_anomaly_detection ? 1 : 0

  name         = "${var.prefix}-runner-anomaly-detector"
  monitor_type = "DIMENSIONAL"
  dimension    = "SERVICE"

  specification = "ANOMALY_DETECTION"

  tags = local.tags
}

resource "aws_ce_anomaly_subscription" "runner" {
  count = var.enable_cost_anomaly_detection && var.budget_sns_topic_arn != "" ? 1 : 0

  name             = "${var.prefix}-runner-anomaly-subscription"
  frequency        = "IMMEDIATE"
  monitor_arn_list = [aws_ce_anomaly_detector.runner[0].arn]

  subscriber {
    type    = "SNS"
    address = var.budget_sns_topic_arn
  }

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_PERCENTAGE"
      values        = [tostring(var.cost_anomaly_threshold_percent)]
      match_options = ["GREATER_THAN_OR_EQUAL"]
    }
  }

  tags = local.tags
}
