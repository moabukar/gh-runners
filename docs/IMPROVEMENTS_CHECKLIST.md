# Improvements Checklist

## 🔴 Critical (Must Fix)

### 1. ✅ Lambda Layer for PyJWT - DONE
- [x] **Issue**: Lambda functions import `jwt` (PyJWT) but it's not in Lambda runtime
- [x] **Fix**: Deploy Lambda layer with dependencies
- [x] **Action**: Added `aws_lambda_layer_version` resource, attached to all Lambda functions

### 2. ✅ Lambda VPC Configuration - DONE
- [x] **Issue**: Lambda functions might need VPC access for Secrets Manager/VPC endpoints
- [x] **Fix**: Make VPC config optional via variables
- [x] **Action**: Added `lambda_vpc_config` variable with conditional VPC attachment and IAM permissions

## 🟡 High Priority (Should Add)

### 3. ✅ CloudWatch Dashboard - DONE
- [x] **Issue**: No visual metrics dashboard
- [x] **Fix**: Add CloudWatch dashboard with key metrics
- [x] **Action**: Created `dashboard.tf` with runner metrics

### 4. ✅ Custom CloudWatch Metrics - DONE
- [x] **Issue**: Lambda functions don't emit custom metrics
- [x] **Fix**: Add CloudWatch metrics for jobs processed, runners launched, etc.
- [x] **Action**: Added `put_metric_data` calls in Lambda functions

### 5. ✅ GitHub API Rate Limiting - DONE
- [x] **Issue**: No rate limit handling for GitHub API calls
- [x] **Fix**: Add exponential backoff and retry logic
- [x] **Action**: Implemented `@retry_github_api` decorator with rate limit awareness

### 6. ✅ Lambda Layer Build in CI/CD - DONE
- [x] **Issue**: Lambda layer build script exists but not automated
- [x] **Fix**: Add step to build and publish layer in CI/CD
- [x] **Action**: Added `build-layer` job to GitHub Actions workflow that builds and publishes layer

### 7. WAF Rules for API Gateway
- [ ] **Issue**: No protection against DDoS/abuse
- [ ] **Fix**: Add AWS WAF rules for rate limiting and geo-blocking
- [ ] **Action**: Create WAF web ACL and attach to API Gateway

### 8. Cost Monitoring
- [ ] **Issue**: No cost alerts or tracking
- [ ] **Fix**: Add CloudWatch metrics and cost anomaly detection
- [ ] **Action**: Create cost metrics and alarms

### 9. Instance Health Checks
- [ ] **Issue**: No health checks for runner instances
- [ ] **Fix**: Add SSM session manager health checks or CloudWatch agent
- [ ] **Action**: Add health check script and monitoring

### 10. ✅ Better Error Context - DONE
- [x] **Issue**: Error messages lack context
- [x] **Fix**: Add structured error logging with request IDs
- [x] **Action**: Enhanced Lambda error handling with request IDs, structured logging, and better context in webhook.py

## 🟢 Medium Priority (Nice to Have)

### 11. Multi-Region Support
- [ ] Add variables for region selection
- [ ] Document multi-region deployment patterns
- [ ] Add region-specific resource tags

### 12. Spot Instance Interruption Handling
- [ ] Add instance metadata handler for Spot interruptions
- [ ] Add CloudWatch event for Spot termination warnings
- [ ] Implement graceful job cancellation

### 13. Runner Version Management
- [ ] Add variable for runner version
- [ ] Auto-update runner version check
- [ ] Add AMI version validation

### 14. Cost Allocation Tags
- [ ] Add more granular cost allocation tags
- [ ] Tag by repository/project
- [ ] Add CostCenter tags

### 15. ✅ Lambda Reserved Concurrency - DONE
- [x] Add variable for Lambda reserved concurrency
- [x] Prevent Lambda throttling
- [x] Better scaling behavior

### 16. SQS Queue Metrics
- [ ] Add custom SQS metrics
- [ ] Alert on queue depth
- [ ] Alert on processing time

### 17. ✅ GitHub API Retry Logic - DONE (duplicate of #5)
- [x] Implement exponential backoff
- [x] Handle 403 rate limit errors
- [x] Add retry decorator

### 18. CloudTrail Logging
- [ ] Enable CloudTrail for API calls
- [ ] Add log file validation
- [ ] Centralized logging

### 19. Testing Framework
- [ ] Add unit tests for Lambda functions
- [ ] Add integration tests with Terratest
- [ ] Add test coverage reporting

### 20. Documentation Improvements
- [ ] Add troubleshooting guide
- [ ] Add architecture diagrams
- [ ] Add disaster recovery procedures
- [ ] Add cost optimization guide

## 🔵 Low Priority (Future Enhancements)

### 21. Multi-Environment Support
- [ ] Separate dev/staging/prod configurations
- [ ] Environment-specific variables
- [ ] Cross-environment testing

### 22. Runner Customization
- [ ] Custom user data scripts
- [ ] Additional runner labels via webhook
- [ ] Dynamic instance type selection

### 23. Advanced Monitoring
- [ ] X-Ray tracing for Lambda
- [ ] Performance Insights
- [ ] Custom Grafana dashboards

### 24. Security Enhancements
- [ ] AWS Systems Manager Parameter Store for config
- [ ] Secrets rotation automation
- [ ] Network isolation improvements

### 25. CI/CD Improvements
- [ ] Terraform plan comment on PRs
- [ ] Automated testing in CI
- [ ] Security scanning (Snyk, Checkmarx)
