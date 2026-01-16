################################################################################
# CloudWatch Dashboard
################################################################################
resource "aws_cloudwatch_dashboard" "runners" {
  count = var.enable_dashboard ? 1 : 0

  dashboard_name = "${var.prefix}-github-runners"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["GitHubRunners", "ActiveRunners", { stat = "Average", period = 60 }],
            [".", "RunnerLaunched", { stat = "Sum", period = 300 }],
            [".", "RunnersSkipped", { stat = "Sum", period = 300 }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Runner Activity"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", { stat = "Sum", period = 300, dimensions = { FunctionName = aws_lambda_function.webhook.function_name } }],
            [".", "Errors", { stat = "Sum", period = 300, dimensions = { FunctionName = aws_lambda_function.webhook.function_name } }],
            [".", ".", { stat = "Sum", period = 300, dimensions = { FunctionName = aws_lambda_function.scale_up.function_name } }],
            [".", ".", { stat = "Sum", period = 300, dimensions = { FunctionName = aws_lambda_function.scale_down.function_name } }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Lambda Invocations & Errors"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", { stat = "Average", period = 60, dimensions = { QueueName = aws_sqs_queue.webhook.name } }],
            [".", "ApproximateNumberOfMessagesNotVisible", { stat = "Average", period = 60, dimensions = { QueueName = aws_sqs_queue.webhook.name } }],
            [".", "ApproximateNumberOfMessagesVisible", { stat = "Average", period = 60, dimensions = { QueueName = aws_sqs_queue.webhook_dlq.name }, color = "#FF0000" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "SQS Queue Depth"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["GitHubRunners", "RunnerLaunchErrors", { stat = "Sum", period = 300 }],
            ["AWS/Lambda", "Throttles", { stat = "Sum", period = 300, dimensions = { FunctionName = aws_lambda_function.scale_up.function_name } }],
            [".", ".", { stat = "Sum", period = 300, dimensions = { FunctionName = aws_lambda_function.webhook.function_name } }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Errors & Throttles"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        properties = {
          metrics = [
            ["GitHubRunners", "ScaleUpProcessingTime", { stat = "Average", period = 300 }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Lambda Processing Time"
          period  = 300
        }
      }
    ]
  })
}