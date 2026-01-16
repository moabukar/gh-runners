# Operations Guide

## Monitoring

### CloudWatch Logs

```bash
# Webhook Lambda
aws logs tail /aws/lambda/{prefix}-runner-webhook --follow

# Scale-up Lambda
aws logs tail /aws/lambda/{prefix}-runner-scale-up --follow

# Scale-down Lambda
aws logs tail /aws/lambda/{prefix}-runner-scale-down --follow
```

### Key Metrics

- SQS queue depth (alert if > 10 for 5 min)
- DLQ messages (alert if > 0)
- Lambda error rate (alert if > 5%)
- Running instances count

## Debugging

### SSH to Runner (via SSM)

```bash
aws ssm start-session --target i-xxxxxxxxx
```

### Check Runner Logs

```bash
cat /var/log/runner-setup.log
```

## Maintenance

### Update Runner Version

1. Edit `packer/github-runner.pkr.hcl`
2. Run AMI build workflow
3. New runners will use updated AMI

### Rotate GitHub App Key

1. Generate new key in GitHub App settings
2. Update Secrets Manager
3. Redeploy Terraform
