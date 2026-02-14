# Scenario 5: ECR and Lambda - Problematic Configuration

## Overview

This scenario demonstrates common security and operational issues with Amazon ECR and AWS Lambda that violate AWS Well-Architected Framework principles.

## Issues Demonstrated

### ECR Issues (5 issues)

1. **Image Scanning Disabled**
   - Vulnerability: Undetected security vulnerabilities in container images
   - Well-Architected Pillar: Security
   - Impact: High

2. **Mutable Image Tags**
   - Vulnerability: Tags can be overwritten, breaking deployment reproducibility
   - Well-Architected Pillar: Operational Excellence
   - Impact: Medium

3. **No Lifecycle Policy**
   - Vulnerability: Old images accumulate, increasing storage costs
   - Well-Architected Pillar: Cost Optimization
   - Impact: Medium

4. **Overly Permissive Repository Policy**
   - Vulnerability: Any AWS account can pull images
   - Well-Architected Pillar: Security
   - Impact: Critical

5. **No Encryption Configuration**
   - Vulnerability: Images not encrypted with customer-managed keys
   - Well-Architected Pillar: Security
   - Impact: Medium

### Lambda Issues (10 issues)

1. **Plaintext Secrets in Environment Variables**
   - Vulnerability: Database passwords and API keys exposed
   - Well-Architected Pillar: Security
   - Impact: Critical

2. **Excessive IAM Permissions**
   - Vulnerability: AdministratorAccess attached to Lambda role
   - Well-Architected Pillar: Security
   - Impact: Critical

3. **No Dead Letter Queue**
   - Vulnerability: Failed invocations are lost
   - Well-Architected Pillar: Reliability
   - Impact: High

4. **No X-Ray Tracing**
   - Vulnerability: Difficult to debug and monitor
   - Well-Architected Pillar: Operational Excellence
   - Impact: Medium

5. **Public Function URL Without Authentication**
   - Vulnerability: Anyone can invoke the function
   - Well-Architected Pillar: Security
   - Impact: Critical

6. **Unlimited CloudWatch Logs Retention**
   - Vulnerability: Logs stored indefinitely, increasing costs
   - Well-Architected Pillar: Cost Optimization
   - Impact: Medium

7. **No VPC Configuration**
   - Vulnerability: No network isolation
   - Well-Architected Pillar: Security
   - Impact: High

8. **No Versioning or Aliases**
   - Vulnerability: Difficult to rollback deployments
   - Well-Architected Pillar: Operational Excellence
   - Impact: Medium

9. **Excessive Timeout (900s)**
   - Vulnerability: Potential for runaway functions, high costs
   - Well-Architected Pillar: Cost Optimization
   - Impact: Medium

10. **Excessive Memory (10GB)**
    - Vulnerability: Unnecessary resource allocation, high costs
    - Well-Architected Pillar: Cost Optimization
    - Impact: High

## Deployment

```bash
cd scenarios/05-ecr-lambda-problematic
terraform init
terraform apply
```

## Testing Issues

### Test ECR Repository Policy
```bash
# Try to pull image from another AWS account (should succeed - ISSUE)
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <repository-url>
```

### Test Lambda Function URL
```bash
# Access function without authentication (should succeed - ISSUE)
curl $(terraform output -raw lambda_function_url)
```

### Check Environment Variables
```bash
# View plaintext secrets (ISSUE)
aws lambda get-function-configuration --function-name $(terraform output -raw lambda_function_name) --query 'Environment.Variables'
```

## Cost Estimate

- ECR: ~$1/month (minimal storage)
- Lambda: ~$5-50/month (depending on invocations)
- CloudWatch Logs: ~$5-20/month (unlimited retention)
- **Total**: ~$11-71/month

## Cleanup

```bash
terraform destroy
```

## Related Scenarios

- **Scenario 6**: Improved ECR and Lambda configuration
