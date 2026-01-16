################################################################################
# AWS WAF for API Gateway
################################################################################

resource "aws_wafv2_web_acl" "api_gateway" {
  count = var.enable_waf ? 1 : 0

  name  = "${var.prefix}-runner-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # Rate limiting rule
  rule {
    name     = "RateLimitRule"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.prefix}-runner-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - Common Rule Set (OWASP Top 10)
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.prefix}-runner-common-rules"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - Known Bad Inputs
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.prefix}-runner-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - Linux Operating System
  rule {
    name     = "AWSManagedRulesLinuxRuleSet"
    priority = 4

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesLinuxRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.prefix}-runner-linux-rules"
      sampled_requests_enabled   = true
    }
  }

  # Geo-blocking (optional)
  dynamic "rule" {
    for_each = var.waf_blocked_countries != null && length(var.waf_blocked_countries) > 0 ? [1] : []
    content {
      name     = "GeoBlockRule"
      priority = 5

      action {
        block {}
      }

      statement {
        geo_match_statement {
          country_codes = var.waf_blocked_countries
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.prefix}-runner-geo-block"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.prefix}-runner-waf"
    sampled_requests_enabled   = true
  }

  tags = local.tags
}

resource "aws_wafv2_web_acl_association" "api_gateway" {
  count = var.enable_waf ? 1 : 0

  resource_arn = aws_apigatewayv2_api.webhook.arn
  web_acl_arn  = aws_wafv2_web_acl.api_gateway[0].arn
}

resource "aws_cloudwatch_log_group" "waf" {
  count = var.enable_waf && var.enable_waf_logging ? 1 : 0

  name              = "aws-waf-logs-${var.prefix}-runner"
  retention_in_days = var.log_retention_days
  tags              = local.tags
}

resource "aws_wafv2_web_acl_logging_configuration" "api_gateway" {
  count = var.enable_waf && var.enable_waf_logging ? 1 : 0

  resource_arn            = aws_wafv2_web_acl.api_gateway[0].arn
  log_destination_configs = [aws_cloudwatch_log_group.waf[0].arn]
}
