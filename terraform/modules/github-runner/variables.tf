variable "prefix" {
  type        = string
  description = "Prefix for all resource names"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.prefix)) && length(var.prefix) <= 20
    error_message = "Prefix must be lowercase alphanumeric with hyphens, max 20 chars."
  }
}

variable "github_app" {
  type = object({
    id                 = string
    installation_id    = string
    private_key_base64 = string
    webhook_secret     = string
  })
  sensitive   = true
  description = "GitHub App credentials"
}

variable "github_org" {
  type        = string
  description = "GitHub organisation name"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID for runners"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for runners"
}

variable "instance_types" {
  type        = list(string)
  default     = ["m5.large", "m5a.large", "m5.xlarge"]
  description = "EC2 instance types for runners"
}

variable "spot_enabled" {
  type        = bool
  default     = true
  description = "Use Spot instances"
}

variable "runners_maximum_count" {
  type        = number
  default     = 10
  description = "Maximum concurrent runners"
  validation {
    condition     = var.runners_maximum_count > 0 && var.runners_maximum_count <= 100
    error_message = "Runners maximum count must be between 1 and 100."
  }
}

variable "minimum_running_time_in_minutes" {
  type        = number
  default     = 5
  description = "Minimum time before termination"
}

variable "runner_labels" {
  type        = list(string)
  default     = ["self-hosted", "linux", "x64"]
  description = "Runner labels"
}

variable "runner_group" {
  type        = string
  default     = "default"
  description = "Runner group name"
}

variable "runner_additional_policy_arns" {
  type        = list(string)
  default     = []
  description = "Additional IAM policies for runners"
}

variable "ami_filter" {
  type = object({
    name  = list(string)
    state = list(string)
  })
  default = {
    name  = ["github-runner-*"]
    state = ["available"]
  }
  description = "AMI filter"
}

variable "ami_owners" {
  type        = list(string)
  default     = ["self"]
  description = "AMI owner account IDs"
}

variable "scale_down_schedule" {
  type        = string
  default     = "rate(1 minute)"
  description = "Scale-down schedule"
}

variable "key_name" {
  type        = string
  default     = ""
  description = "EC2 key pair name"
}

variable "enable_ssm" {
  type        = bool
  default     = true
  description = "Enable SSM"
}

variable "log_retention_days" {
  type        = number
  default     = 30
  description = "Log retention days"
}

variable "log_level" {
  type        = string
  default     = "INFO"
  description = "Lambda log level"
  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR"], upper(var.log_level))
    error_message = "Log level must be one of: DEBUG, INFO, WARNING, ERROR."
  }
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags"
}

variable "api_gateway_throttle_burst" {
  type        = number
  default     = 100
  description = "API Gateway throttle burst limit"
}

variable "api_gateway_throttle_rate" {
  type        = number
  default     = 50
  description = "API Gateway throttle rate limit"
}

variable "alarm_sns_topic_arn" {
  type        = string
  default     = ""
  description = "SNS topic ARN for CloudWatch alarms"
}

variable "lambda_layer_arn" {
  type        = string
  default     = ""
  description = "ARN of existing Lambda layer for Python dependencies (PyJWT, etc.). If empty, will create new layer from zip_path."
}

variable "lambda_layer_zip_path" {
  type        = string
  default     = ""
  description = "Local path to Lambda layer zip file. Required if lambda_layer_arn is empty."
}

variable "lambda_reserved_concurrency" {
  type        = number
  default     = -1
  description = "Reserved concurrent executions for Lambda functions (-1 for unreserved)"
  validation {
    condition     = var.lambda_reserved_concurrency == -1 || (var.lambda_reserved_concurrency > 0 && var.lambda_reserved_concurrency <= 1000)
    error_message = "Reserved concurrency must be -1 (unreserved) or between 1 and 1000."
  }
}

variable "enable_dashboard" {
  type        = bool
  default     = true
  description = "Enable CloudWatch dashboard"
}

variable "enable_waf" {
  type        = bool
  default     = true
  description = "Enable AWS WAF for API Gateway"
}

variable "waf_rate_limit" {
  type        = number
  default     = 2000
  description = "WAF rate limit per 5 minutes per IP"
  validation {
    condition     = var.waf_rate_limit >= 100 && var.waf_rate_limit <= 100000
    error_message = "WAF rate limit must be between 100 and 100000."
  }
}

variable "waf_blocked_countries" {
  type        = list(string)
  default     = null
  description = "List of country codes to block (ISO 3166-1 alpha-2). Null to allow all."
}

variable "enable_waf_logging" {
  type        = bool
  default     = true
  description = "Enable WAF logging to CloudWatch"
}

variable "enable_xray" {
  type        = bool
  default     = true
  description = "Enable AWS X-Ray tracing for Lambda functions and API Gateway"
}

variable "enable_cloudtrail" {
  type        = bool
  default     = true
  description = "Enable CloudTrail for audit logging"
}

variable "cloudtrail_multi_region" {
  type        = bool
  default     = true
  description = "Enable multi-region CloudTrail"
}

variable "cloudtrail_log_retention_days" {
  type        = number
  default     = 90
  description = "CloudTrail S3 log retention in days"
  validation {
    condition     = var.cloudtrail_log_retention_days >= 1 && var.cloudtrail_log_retention_days <= 2555
    error_message = "CloudTrail log retention must be between 1 and 2555 days."
  }
}

variable "enable_budget" {
  type        = bool
  default     = false
  description = "Enable AWS Budget for cost monitoring"
}

variable "budget_limit_amount" {
  type        = number
  default     = 100
  description = "Budget limit amount"
}

variable "budget_limit_unit" {
  type        = string
  default     = "USD"
  description = "Budget limit unit (USD, EUR, etc.)"
}

variable "budget_time_unit" {
  type        = string
  default     = "MONTHLY"
  description = "Budget time unit (MONTHLY, QUARTERLY, ANNUALLY)"
  validation {
    condition     = contains(["MONTHLY", "QUARTERLY", "ANNUALLY"], upper(var.budget_time_unit))
    error_message = "Budget time unit must be MONTHLY, QUARTERLY, or ANNUALLY."
  }
}

variable "budget_time_period_start" {
  type        = string
  default     = ""
  description = "Budget time period start (YYYY-MM-DD_HH:MM). Empty for current date."
}

variable "budget_threshold_percent" {
  type        = number
  default     = 80
  description = "Budget threshold percentage for actual costs"
  validation {
    condition     = var.budget_threshold_percent > 0 && var.budget_threshold_percent <= 200
    error_message = "Budget threshold must be between 1 and 200 percent."
  }
}

variable "budget_forecasted_threshold_percent" {
  type        = number
  default     = 100
  description = "Budget threshold percentage for forecasted costs"
  validation {
    condition     = var.budget_forecasted_threshold_percent > 0 && var.budget_forecasted_threshold_percent <= 200
    error_message = "Forecasted budget threshold must be between 1 and 200 percent."
  }
}

variable "budget_notification_emails" {
  type        = list(string)
  default     = []
  description = "Email addresses for budget notifications"
}

variable "budget_sns_topic_arn" {
  type        = string
  default     = ""
  description = "SNS topic ARN for budget notifications"
}

variable "enable_cost_anomaly_detection" {
  type        = bool
  default     = false
  description = "Enable Cost Anomaly Detection"
}

variable "cost_anomaly_threshold_percent" {
  type        = number
  default     = 50
  description = "Cost anomaly threshold percentage"
  validation {
    condition     = var.cost_anomaly_threshold_percent > 0 && var.cost_anomaly_threshold_percent <= 200
    error_message = "Cost anomaly threshold must be between 1 and 200 percent."
  }
}

variable "lambda_vpc_config" {
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default     = null
  description = "Optional VPC configuration for Lambda functions (needed for VPC endpoints or private resources)"
}
