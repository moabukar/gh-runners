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
