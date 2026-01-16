# Incident Response Runbook

## Overview

This document outlines procedures for responding to incidents affecting the GitHub Runners infrastructure.

## Severity Levels

### P1 - Critical (Immediate Response)
- All runners down, no jobs can execute
- Security breach detected
- Data loss or corruption
- Complete service outage

**Response Time**: 15 minutes  
**Target Resolution**: 1 hour

### P2 - High (Urgent)
- Partial runner failure (>50% unavailable)
- Performance degradation (jobs timing out)
- Cost anomalies (>150% expected)

**Response Time**: 1 hour  
**Target Resolution**: 4 hours

### P3 - Medium
- Individual runner failures
- Minor performance issues
- Non-critical feature degradation

**Response Time**: 4 hours  
**Target Resolution**: 1 business day

### P4 - Low
- Minor issues, workarounds available
- Non-urgent improvements

**Response Time**: 1 business day  
**Target Resolution**: 1 week

## On-Call Responsibilities

### Primary On-Call Engineer
- Monitor alerts and respond to incidents
- Escalate to secondary if unavailable
- Document incidents and resolution

### Secondary On-Call Engineer
- Backup to primary
- Available for escalation

### Escalation Path
1. Primary On-Call (15 min)
2. Secondary On-Call (15 min)
3. Team Lead (30 min)
4. Engineering Manager (1 hour)

## Common Incidents & Resolution

### All Runners Down

**Symptoms:**
- No EC2 instances running
- CloudWatch shows no active runners
- GitHub shows "No runners available"

**Diagnosis:**
```bash
# Check Lambda logs
aws logs tail /aws/lambda/{prefix}-runner-scale-up --follow

# Check SQS queue depth
aws sqs get-queue-attributes \
  --queue-url {SQS_QUEUE_URL} \
  --attribute-names ApproximateNumberOfMessages

# Check DLQ for failures
aws sqs get-queue-attributes \
  --queue-url {DLQ_URL} \
  --attribute-names ApproximateNumberOfMessages
```

**Resolution Steps:**
1. Check Lambda function errors in CloudWatch
2. Verify GitHub App credentials in Secrets Manager
3. Check EC2 instance limits/quota
4. Review recent Terraform deployments
5. Check AMI availability
6. Restart scale-up Lambda if needed

**Rollback:**
```bash
# Manually launch runner for urgent work
aws ec2 run-instances \
  --image-id {AMI_ID} \
  --instance-type m5.large \
  --subnet-id {SUBNET_ID} \
  --security-group-ids {SG_ID} \
  --iam-instance-profile Arn={PROFILE_ARN}
```

### High Error Rate in Lambda Functions

**Symptoms:**
- CloudWatch alarms firing
- DLQ has messages
- High Lambda error rate

**Diagnosis:**
```bash
# Check error logs
aws logs filter-log-events \
  --log-group-name /aws/lambda/{prefix}-runner-webhook \
  --filter-pattern "ERROR"

# Check X-Ray traces for errors
aws xray get-trace-summaries \
  --start-time $(date -u -d '1 hour ago' +%s) \
  --end-time $(date -u +%s) \
  --filter-expression "error = true"
```

**Resolution Steps:**
1. Identify error pattern from logs
2. Check GitHub API rate limits (check headers)
3. Verify Secrets Manager access
4. Check VPC/network connectivity if using VPC
5. Review recent code changes

**Common Causes:**
- GitHub API rate limiting → Add retry logic, wait
- Secrets Manager permission issues → Check IAM
- Network connectivity → Check VPC endpoints/security groups
- Invalid webhook signature → Verify webhook secret

### Cost Anomaly

**Symptoms:**
- Budget alert fired
- Unexpected high AWS costs
- Anomaly detection alert

**Diagnosis:**
```bash
# Check Cost Explorer
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost

# Check running instances
aws ec2 describe-instances \
  --filters "Name=tag:Purpose,Values=github-runner" \
            "Name=instance-state-name,Values=running"
```

**Resolution Steps:**
1. Identify cost source (EC2, Lambda, SQS, etc.)
2. Check for stuck/leaked resources
3. Review runner count vs expected
4. Check for Spot instance pricing changes
5. Terminate unnecessary instances

### Webhook Not Receiving Events

**Symptoms:**
- No jobs queued in SQS
- GitHub shows jobs but no runners
- Webhook endpoint returning errors

**Diagnosis:**
```bash
# Check API Gateway logs
aws logs tail /aws/apigateway/{prefix}-runner-webhook --follow

# Test webhook endpoint
curl -X POST {WEBHOOK_URL} \
  -H "X-GitHub-Event: workflow_job" \
  -H "X-Hub-Signature-256: sha256=..." \
  -d @test-payload.json

# Check WAF logs
aws logs tail aws-waf-logs-{prefix}-runner --follow
```

**Resolution Steps:**
1. Verify webhook URL in GitHub App settings
2. Check WAF rules (may be blocking)
3. Verify webhook secret matches
4. Check API Gateway throttling limits
5. Review access logs for 401/403 errors

### Runner Stuck/Not Terminating

**Symptoms:**
- Instances running longer than expected
- Scale-down Lambda not working
- High EC2 costs

**Diagnosis:**
```bash
# Check running instances age
aws ec2 describe-instances \
  --filters "Name=tag:Purpose,Values=github-runner" \
            "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].[InstanceId,LaunchTime,Tags[?Key==`JobId`].Value|[0]]'

# Check scale-down Lambda
aws logs tail /aws/lambda/{prefix}-runner-scale-down --follow
```

**Resolution Steps:**
1. Manually terminate stuck instances
2. Check scale-down Lambda logs
3. Verify EventBridge schedule is enabled
4. Review runner health checks

## Incident Communication

### Internal Communication
- **Slack Channel**: #github-runners-incidents
- **Status Page**: Update AWS Systems Manager Status (if configured)
- **Email**: Alert team via SNS notifications

### External Communication
- **GitHub Status**: Update if service impact
- **Users**: Communicate via GitHub Issues (if needed)

## Post-Incident

### Post-Mortem Process
1. **Within 24 hours**: Initial post-mortem meeting
2. **Within 1 week**: Written post-mortem document
3. **Action Items**: Track in GitHub Issues with label `incident-followup`

### Post-Mortem Template

```markdown
# Incident: [Title]

**Date**: [Date/Time]
**Duration**: [Duration]
**Severity**: P[X]
**Status**: Resolved

## Summary
[Brief description]

## Timeline
- [Time] - [Event]
- [Time] - [Event]

## Root Cause
[Detailed root cause analysis]

## Impact
- Users affected: [Number]
- Jobs failed: [Number]
- Cost impact: [Amount]

## Resolution
[Steps taken to resolve]

## Action Items
- [ ] [Action item 1]
- [ ] [Action item 2]

## Lessons Learned
[What we learned]
```

## Contact Information

### Primary On-Call
- **Slack**: @oncall-primary
- **PagerDuty**: [On-call rotation URL]

### Secondary On-Call
- **Slack**: @oncall-secondary

### Escalation
- **Team Lead**: [Name] - [Contact]
- **Engineering Manager**: [Name] - [Contact]

## References

- [Operations Guide](OPERATIONS.md)
- [Disaster Recovery Procedures](DISASTER_RECOVERY.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)
- AWS Console: [Link]
- CloudWatch Dashboard: [Link]
- X-Ray Service Map: [Link]
