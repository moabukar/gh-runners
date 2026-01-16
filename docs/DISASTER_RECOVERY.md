# Disaster Recovery Runbook

## Overview

This document outlines disaster recovery (DR) procedures for the GitHub Runners infrastructure.

## Recovery Objectives

- **RTO (Recovery Time Objective)**: 2 hours
- **RPO (Recovery Point Objective)**: 5 minutes (SQS message retention)
- **Availability Target**: 99.9% (8.76 hours downtime per year)

## Risk Assessment

### High-Risk Scenarios

1. **Regional AWS Outage**
   - Impact: Complete service loss
   - Mitigation: Multi-region deployment
   - Recovery: Failover to secondary region

2. **Secrets Compromise**
   - Impact: Security breach, service disruption
   - Mitigation: Secrets rotation, access monitoring
   - Recovery: Rotate secrets, redeploy

3. **Terraform State Loss**
   - Impact: Unable to manage infrastructure
   - Mitigation: S3 backend with versioning, backups
   - Recovery: Restore from backup

4. **GitHub App Credentials Loss**
   - Impact: Cannot authenticate with GitHub
   - Mitigation: Backup credentials in secure vault
   - Recovery: Restore credentials, redeploy

5. **Data Loss (Secrets Manager)**
   - Impact: Cannot authenticate, no runners
   - Mitigation: Regular backups, cross-region replication
   - Recovery: Restore from backup

## Backup Procedures

### Daily Backups

#### Terraform State
- **Location**: S3 bucket with versioning enabled
- **Retention**: 30 days
- **Backup**: Automatic via S3 versioning
- **Verification**: Weekly restore test

#### Secrets Manager
- **Location**: Cross-region replication (if enabled)
- **Retention**: 90 days
- **Backup**: Manual export to secure vault (quarterly)
- **Verification**: Quarterly restore test

```bash
# Export secret (quarterly backup)
aws secretsmanager get-secret-value \
  --secret-id {prefix}-github-app \
  --query SecretString \
  --output text | \
  gpg --encrypt --recipient admin@company.com > \
  backup-$(date +%Y%m%d)-github-app-secret.gpg
```

#### AMI Snapshots
- **Location**: Same region as AMI
- **Retention**: 30 days
- **Backup**: Automatic via Packer builds
- **Verification**: Monthly AMI rebuild test

### Weekly Backups

#### Configuration Files
- Terraform configuration (Git repository)
- Packer templates (Git repository)
- CI/CD workflows (Git repository)

**Location**: Git repository with remote backup

## Recovery Procedures

### Scenario 1: Regional AWS Outage

**Impact**: Complete service loss in primary region

**Recovery Steps:**

1. **Assess Impact**
   ```bash
   # Check primary region status
   aws ec2 describe-regions --region-names {PRIMARY_REGION}
   ```

2. **Activate Secondary Region**
   - Update Terraform backend configuration
   - Deploy infrastructure to secondary region
   - Update GitHub App webhook URL
   - Verify runners can launch

3. **Monitor Primary Region**
   - Wait for AWS service restoration
   - Verify all services operational

4. **Failback (Optional)**
   - Return to primary region
   - Update webhook URL back to primary
   - Decommission secondary region resources

**Recovery Time**: 1-2 hours

### Scenario 2: Secrets Compromise

**Impact**: Security breach, service disruption

**Recovery Steps:**

1. **Immediate Actions** (15 minutes)
   - Revoke compromised GitHub App credentials
   - Generate new GitHub App private key
   - Update Secrets Manager with new credentials
   - Invalidate all Lambda execution contexts (redeploy)

2. **Verification** (30 minutes)
   - Test webhook authentication
   - Verify runner launch works
   - Check CloudTrail for unauthorized access

3. **Security Audit** (1 hour)
   - Review CloudTrail logs for compromise timeline
   - Check IAM access logs
   - Review GitHub App access logs

**Recovery Time**: 1-2 hours

### Scenario 3: Terraform State Loss

**Impact**: Cannot manage infrastructure via Terraform

**Recovery Steps:**

1. **Restore State from Backup**
   ```bash
   # List S3 object versions
   aws s3api list-object-versions \
     --bucket {TERRAFORM_STATE_BUCKET} \
     --prefix github-runners/prod/terraform.tfstate

   # Restore previous version
   aws s3api get-object \
     --bucket {TERRAFORM_STATE_BUCKET} \
     --key github-runners/prod/terraform.tfstate \
     --version-id {VERSION_ID} \
     terraform.tfstate
   ```

2. **Re-import Resources** (if needed)
   - Document all existing resources
   - Import into Terraform state
   - Verify state matches reality

3. **Verify Infrastructure**
   - Run `terraform plan` to check for drift
   - Fix any inconsistencies

**Recovery Time**: 2-4 hours

### Scenario 4: Complete Infrastructure Loss

**Impact**: All AWS resources deleted or lost

**Recovery Steps:**

1. **Prerequisites Check** (15 minutes)
   - Verify Terraform configuration available
   - Verify GitHub App credentials available
   - Verify AMI exists or can be rebuilt
   - Verify S3 backend accessible

2. **Infrastructure Deployment** (1 hour)
   ```bash
   cd terraform/environments/prod
   terraform init
   terraform plan
   terraform apply
   ```

3. **Configuration** (30 minutes)
   - Update GitHub App webhook URL
   - Verify runners can launch
   - Test end-to-end workflow

4. **Verification** (15 minutes)
   - Run test GitHub Actions workflow
   - Verify metrics/alarms working
   - Check CloudWatch dashboard

**Recovery Time**: 2-3 hours

### Scenario 5: GitHub App Deletion/Compromise

**Impact**: Cannot authenticate with GitHub

**Recovery Steps:**

1. **Create New GitHub App** (30 minutes)
   - Register new GitHub App
   - Generate private key
   - Install to organization
   - Note App ID and Installation ID

2. **Update Secrets Manager** (15 minutes)
   - Update secret with new credentials
   - Verify secret accessible

3. **Redeploy Infrastructure** (30 minutes)
   - Update Terraform variables
   - Apply changes
   - Verify Lambda functions updated

4. **Update Webhook** (15 minutes)
   - Update webhook URL in GitHub App (if changed)
   - Verify webhook events received

**Recovery Time**: 1.5-2 hours

## Testing Procedures

### Monthly DR Drill

**Schedule**: First Monday of each month

**Procedure:**
1. Select random DR scenario
2. Execute recovery procedure (dry-run if possible)
3. Document time to recovery
4. Identify improvements
5. Update runbook

### Quarterly Full Recovery Test

**Schedule**: Quarterly (Q1, Q2, Q3, Q4)

**Procedure:**
1. Create isolated test environment
2. Deploy from scratch
3. Test all scenarios
4. Measure RTO/RPO
5. Generate test report

## Monitoring & Alerts

### DR-Related Alarms

- **Budget Exceeded**: >150% of monthly budget
- **CloudTrail Logging Disabled**: CloudTrail stopped
- **Secrets Manager Access Denied**: IAM permission issues
- **No Active Runners**: >30 minutes with zero runners
- **High Error Rate**: >10% Lambda errors for 5 minutes

### Health Checks

Daily automated checks:
- Terraform state backup exists
- Secrets Manager accessible
- AMI exists and valid
- CloudWatch logs flowing
- Alarms functioning

## Communication Plan

### Internal
- **Channel**: #github-runners-dr
- **Escalation**: Team Lead → Engineering Manager → CTO

### External
- **GitHub Status**: Update service status page
- **Users**: Communicate via GitHub Issues (if extended outage)

## Pre-requisites

### Required Access
- AWS Console access (Admin)
- GitHub Organization Admin access
- Secrets Manager read/write
- S3 state bucket access
- Terraform installed locally

### Required Information
- GitHub App ID and Installation ID (backed up)
- Secrets Manager secret ARNs
- VPC/Subnet IDs for deployment
- Terraform state bucket location
- CloudWatch dashboard URLs

### Required Tools
- AWS CLI configured
- Terraform >= 1.7
- GitHub CLI (optional)
- GPG for secret encryption (backups)

## Success Criteria

Recovery is successful when:
- ✅ All infrastructure resources restored
- ✅ Runners can launch and execute jobs
- ✅ Webhook receiving events
- ✅ Monitoring/alarms operational
- ✅ Cost monitoring active
- ✅ Security controls verified

## Lessons Learned

After each DR event:
1. Document what went well
2. Document what could be improved
3. Update procedures
4. Share with team
5. Schedule follow-up improvements

## References

- [Operations Guide](OPERATIONS.md)
- [Incident Response](INCIDENT_RESPONSE.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)
- AWS Disaster Recovery: https://aws.amazon.com/disaster-recovery/
- Terraform State: https://www.terraform.io/docs/language/state/
