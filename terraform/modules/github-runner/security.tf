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
