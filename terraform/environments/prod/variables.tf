variable "prefix" {
  type        = string
  description = "Prefix for all resource names"
}

variable "github_org" {
  type        = string
  description = "GitHub organisation name"
}

variable "github_app_id" {
  type        = string
  description = "GitHub App ID"
}

variable "github_app_installation_id" {
  type        = string
  description = "GitHub App Installation ID"
}

variable "github_app_private_key_base64" {
  type        = string
  sensitive   = true
  description = "Base64-encoded GitHub App private key"
}

variable "github_webhook_secret" {
  type        = string
  sensitive   = true
  description = "GitHub webhook secret"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs"
}

variable "runners_maximum_count" {
  type        = number
  default     = 10
  description = "Maximum concurrent runners"
}
