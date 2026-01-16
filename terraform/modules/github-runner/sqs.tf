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
