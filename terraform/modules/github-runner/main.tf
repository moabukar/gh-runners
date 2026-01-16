################################################################################
# GitHub Actions Self-Hosted Runners - EC2 Auto-Scaling
################################################################################

locals {
  lambda_runtime = "python3.11"
  lambda_timeout = 60
  tags           = merge(var.tags, { Module = "github-runner" })
}


data "aws_ami" "runner" {
  most_recent = true
  owners      = var.ami_owners

  filter {
    name   = "name"
    values = var.ami_filter.name
  }

  filter {
    name   = "state"
    values = var.ami_filter.state
  }
}

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

################################################################################
# SQS Queues
################################################################################
resource "aws_kms_key" "sqs" {
  description             = "KMS key for SQS encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = local.tags
}

resource "aws_kms_alias" "sqs" {
  name          = "alias/${var.prefix}-runner-sqs"
  target_key_id = aws_kms_key.sqs.key_id
}

resource "aws_sqs_queue" "webhook" {
  name                              = "${var.prefix}-runner-webhook"
  visibility_timeout_seconds        = 120
  message_retention_seconds         = 3600
  receive_wait_time_seconds         = 10
  kms_master_key_id                 = aws_kms_key.sqs.arn
  kms_data_key_reuse_period_seconds = 300

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.webhook_dlq.arn
    maxReceiveCount     = 3
  })

  tags = local.tags
}

resource "aws_sqs_queue" "webhook_dlq" {
  name                              = "${var.prefix}-runner-webhook-dlq"
  message_retention_seconds         = 1209600
  kms_master_key_id                 = aws_kms_key.sqs.arn
  kms_data_key_reuse_period_seconds = 300
  tags                              = local.tags
}

################################################################################
# API Gateway
################################################################################
resource "aws_apigatewayv2_api" "webhook" {
  name          = "${var.prefix}-runner-webhook"
  protocol_type = "HTTP"
  tags          = local.tags
}

resource "aws_apigatewayv2_stage" "webhook" {
  api_id      = aws_apigatewayv2_api.webhook.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = var.api_gateway_throttle_burst
    throttling_rate_limit  = var.api_gateway_throttle_rate
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      status         = "$context.status"
      responseLength = "$context.responseLength"
    })
  }

  tags = local.tags
}

resource "aws_apigatewayv2_integration" "webhook" {
  api_id                 = aws_apigatewayv2_api.webhook.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.webhook.arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "webhook" {
  api_id    = aws_apigatewayv2_api.webhook.id
  route_key = "POST /webhook"
  target    = "integrations/${aws_apigatewayv2_integration.webhook.id}"
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.webhook.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.webhook.execution_arn}/*/*"
}

################################################################################
# Lambda Layer for Python Dependencies
################################################################################
resource "aws_lambda_layer_version" "python_dependencies" {
  count = var.lambda_layer_arn == "" && var.lambda_layer_zip_path != "" ? 1 : 0

  layer_name          = "${var.prefix}-python-dependencies"
  filename            = var.lambda_layer_zip_path
  source_code_hash    = filebase64sha256(var.lambda_layer_zip_path)
  compatible_runtimes = [local.lambda_runtime]

  description = "Python dependencies (PyJWT, boto3, cryptography) for GitHub runner Lambda functions"

  tags = local.tags
}

data "aws_lambda_layer_version" "python_dependencies" {
  count = var.lambda_layer_arn != "" ? 1 : 0

  layer_name = split(":", var.lambda_layer_arn)[6]
  version    = split(":", var.lambda_layer_arn)[7]
}

locals {
  lambda_layers = var.lambda_layer_arn != "" ? [var.lambda_layer_arn] : (var.lambda_layer_zip_path != "" && length(aws_lambda_layer_version.python_dependencies) > 0 ? [aws_lambda_layer_version.python_dependencies[0].arn] : [])
}

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

################################################################################
# Security Group
################################################################################
resource "aws_security_group" "runner" {
  name        = "${var.prefix}-runner"
  description = "Security group for GitHub Actions runners"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${var.prefix}-runner" })
}

################################################################################
# IAM - Runner Instance
################################################################################
resource "aws_iam_role" "runner" {
  name = "${var.prefix}-runner"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = local.tags
}

resource "aws_iam_instance_profile" "runner" {
  name = "${var.prefix}-runner"
  role = aws_iam_role.runner.name
}

resource "aws_iam_role_policy_attachment" "runner_ssm" {
  count      = var.enable_ssm ? 1 : 0
  role       = aws_iam_role.runner.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "runner_ecr" {
  role       = aws_iam_role.runner.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "runner_additional" {
  for_each   = toset(var.runner_additional_policy_arns)
  role       = aws_iam_role.runner.name
  policy_arn = each.value
}

################################################################################
# IAM - Lambda Webhook
################################################################################
resource "aws_iam_role" "lambda_webhook" {
  name = "${var.prefix}-lambda-webhook"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "lambda_webhook" {
  name = "webhook-policy"
  role = aws_iam_role.lambda_webhook.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = aws_sqs_queue.webhook.arn
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.github_app.arn
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = aws_kms_key.sqs.arn
      }
    ], var.lambda_vpc_config != null ? [{
      Effect = "Allow"
      Action = [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface",
        "ec2:AssignPrivateIpAddresses",
        "ec2:UnassignPrivateIpAddresses"
      ]
      Resource = "*"
    }] : [])
  })
}

################################################################################
# IAM - Lambda Scale Up
################################################################################
resource "aws_iam_role" "lambda_scale_up" {
  name = "${var.prefix}-lambda-scale-up"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = local.tags
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_iam_role_policy" "lambda_scale_up" {
  name = "scale-up-policy"
  role = aws_iam_role.lambda_scale_up.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["cloudwatch:PutMetricData"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "GitHubRunners"
          }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = aws_sqs_queue.webhook.arn
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.github_app.arn
      },
      {
        Effect = "Allow"
        Action = ["ec2:RunInstances", "ec2:CreateTags"]
        Resource = [
          "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:instance/*",
          "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:volume/*",
          "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:network-interface/*",
          "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:launch-template/*",
          "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:spot-instances-request/*"
        ]
        Condition = {
          StringEquals = {
            "ec2:InstanceType" = var.instance_types
          }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:DescribeInstances", "ec2:DescribeInstanceStatus", "ec2:DescribeSpotInstanceRequests"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = aws_iam_role.runner.arn
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = aws_kms_key.sqs.arn
      }
    ], var.lambda_vpc_config != null ? [{
      Effect = "Allow"
      Action = [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface",
        "ec2:AssignPrivateIpAddresses",
        "ec2:UnassignPrivateIpAddresses"
      ]
      Resource = "*"
    }] : [])
  })
}

resource "aws_iam_role_policy_attachment" "lambda_scale_up_vpc" {
  count      = var.lambda_vpc_config != null ? 1 : 0
  role       = aws_iam_role.lambda_scale_up.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

################################################################################
# IAM - Lambda Scale Down
################################################################################
resource "aws_iam_role" "lambda_scale_down" {
  name = "${var.prefix}-lambda-scale-down"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "lambda_scale_down" {
  name = "scale-down-policy"
  role = aws_iam_role.lambda_scale_down.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.github_app.arn
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:DescribeInstances"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:TerminateInstances"]
        Resource = "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:instance/*"
        Condition = {
          StringEquals = {
            "ec2:ResourceTag/Purpose" = "github-runner"
          }
        }
      }
    ], var.lambda_vpc_config != null ? [{
      Effect = "Allow"
      Action = [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface",
        "ec2:AssignPrivateIpAddresses",
        "ec2:UnassignPrivateIpAddresses"
      ]
      Resource = "*"
    }] : [])
  })
}

resource "aws_iam_role_policy_attachment" "lambda_webhook_vpc" {
  count      = var.lambda_vpc_config != null ? 1 : 0
  role       = aws_iam_role.lambda_webhook.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_scale_down_vpc" {
  count      = var.lambda_vpc_config != null ? 1 : 0
  role       = aws_iam_role.lambda_scale_down.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

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

################################################################################
# CloudWatch Alarms
################################################################################
resource "aws_cloudwatch_metric_alarm" "lambda_webhook_errors" {
  name                = "${var.prefix}-runner-webhook-errors"
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
  name                = "${var.prefix}-runner-scale-up-errors"
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
  name                = "${var.prefix}-runner-sqs-dlq-messages"
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
