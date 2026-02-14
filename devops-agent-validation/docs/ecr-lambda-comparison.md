# ECR and Lambda Scenarios Comparison

## Overview

This document compares Scenario 5 (Problematic) and Scenario 6 (Improved) for ECR and Lambda configurations.

## Detailed Comparison

### ECR Configuration

| Feature | Scenario 5 (Problematic) | Scenario 6 (Improved) | Impact |
|---------|-------------------------|----------------------|--------|
| **Image Scanning** | ❌ Disabled | ✅ Enabled on push | High - Detects vulnerabilities early |
| **Image Tag Mutability** | ❌ Mutable | ✅ Immutable | Medium - Ensures deployment reproducibility |
| **Lifecycle Policy** | ❌ None | ✅ Keep last 10, remove untagged after 7 days | Medium - Reduces storage costs |
| **Repository Policy** | ❌ Open to all AWS accounts (*) | ✅ Least privilege (specific role only) | Critical - Prevents unauthorized access |
| **Encryption** | ❌ Default (AWS managed) | ✅ KMS (Customer managed) | Medium - Enhanced data protection |
| **Cost per month** | ~$1 | ~$1 | Similar with lifecycle policy |

### Lambda Configuration

| Feature | Scenario 5 (Problematic) | Scenario 6 (Improved) | Impact |
|---------|-------------------------|----------------------|--------|
| **Secrets Management** | ❌ Plaintext in env vars | ✅ AWS Secrets Manager | Critical - Prevents credential exposure |
| **IAM Permissions** | ❌ AdministratorAccess | ✅ Least privilege | Critical - Reduces blast radius |
| **Dead Letter Queue** | ❌ None | ✅ SQS DLQ configured | High - Prevents data loss |
| **Tracing** | ❌ PassThrough | ✅ X-Ray Active | Medium - Improves observability |
| **Function URL Auth** | ❌ None (public) | ✅ AWS IAM | Critical - Prevents unauthorized access |
| **Log Retention** | ❌ Unlimited | ✅ 30 days | Medium - Controls costs |
| **VPC Configuration** | ❌ None | ✅ Private subnets | High - Network isolation |
| **Versioning** | ❌ None | ✅ Aliases configured | Medium - Enables rollback |
| **Timeout** | ❌ 900s (15 min) | ✅ 30s | Medium - Prevents runaway functions |
| **Memory** | ❌ 10GB | ✅ 512MB | High - Significant cost savings |
| **Concurrent Executions** | ❌ Unlimited | ✅ Reserved (10) | Medium - Cost control |
| **CloudWatch Alarms** | ❌ None | ✅ Errors & Duration | Medium - Proactive monitoring |
| **Cost per month** | ~$50-70 | ~$10-40 | 50-60% cost reduction |

## Security Comparison

### Scenario 5 Security Issues

1. **Critical Issues (5)**
   - Plaintext secrets in environment variables
   - AdministratorAccess IAM permissions
   - Public Function URL without authentication
   - ECR repository open to all AWS accounts
   - No network isolation (VPC)

2. **High Issues (3)**
   - No dead letter queue (data loss risk)
   - No VPC configuration
   - Excessive memory allocation

3. **Medium Issues (7)**
   - No image scanning
   - Mutable image tags
   - No lifecycle policy
   - No X-Ray tracing
   - Unlimited log retention
   - No versioning/aliases
   - Excessive timeout

### Scenario 6 Security Improvements

1. **Critical Improvements (5)**
   - Secrets stored in AWS Secrets Manager with encryption
   - Least privilege IAM role (only necessary permissions)
   - IAM authentication on Function URL
   - ECR repository policy restricted to specific role
   - VPC configuration with private subnets

2. **High Improvements (3)**
   - Dead letter queue configured
   - Network isolation via VPC
   - Right-sized memory allocation

3. **Medium Improvements (7)**
   - Image scanning enabled
   - Immutable image tags
   - Lifecycle policy configured
   - X-Ray tracing active
   - 30-day log retention
   - Versioning with aliases
   - Appropriate timeout

## Cost Analysis

### Monthly Cost Breakdown

#### Scenario 5 (Problematic)
- ECR: $1 (minimal storage, no lifecycle)
- Lambda compute: $30-50 (10GB memory, high invocations)
- CloudWatch Logs: $10-20 (unlimited retention)
- **Total: $41-71/month**

#### Scenario 6 (Improved)
- ECR: $1 (with lifecycle policy)
- Lambda compute: $5-20 (512MB memory, optimized)
- CloudWatch Logs: $2-5 (30-day retention)
- Secrets Manager: $0.40
- KMS: $1
- X-Ray: $0.50-2
- **Total: $10-29/month**

**Savings: $31-42/month (60-75% reduction)**

## Well-Architected Framework Compliance

| Pillar | Scenario 5 | Scenario 6 |
|--------|-----------|-----------|
| **Operational Excellence** | ❌ Poor | ✅ Good |
| **Security** | ❌ Critical Issues | ✅ Compliant |
| **Reliability** | ❌ No DLQ | ✅ DLQ + Monitoring |
| **Performance Efficiency** | ⚠️ Over-provisioned | ✅ Right-sized |
| **Cost Optimization** | ❌ Wasteful | ✅ Optimized |

## DevOps Agent Investigation Prompts

### For Scenario 5 (Problematic)

```
Investigate security and operational issues in ECR and Lambda resources in us-east-1:

ECR Issues:
- Repository with name containing "problematic-repo"
- Check image scanning configuration
- Review repository policies for overly permissive access
- Verify lifecycle policies exist

Lambda Issues:
- Function with name containing "function-problematic"
- Check for plaintext secrets in environment variables
- Review IAM role permissions (look for excessive permissions)
- Verify dead letter queue configuration
- Check X-Ray tracing status
- Review function URL authentication settings
- Verify VPC configuration
- Check CloudWatch Logs retention settings
```

### For Scenario 6 (Improved)

```
Verify security best practices in ECR and Lambda resources in us-east-1:

ECR Verification:
- Repository with name containing "improved-repo"
- Confirm image scanning is enabled
- Verify immutable tags configuration
- Check KMS encryption
- Review lifecycle policies

Lambda Verification:
- Function with name containing "function-improved"
- Verify Secrets Manager integration
- Confirm least privilege IAM permissions
- Check dead letter queue configuration
- Verify X-Ray tracing is active
- Confirm IAM authentication on function URL
- Verify VPC configuration
- Check CloudWatch Logs retention (should be 30 days)
- Verify CloudWatch alarms exist
```

## Testing Scenarios

### Scenario 5 Testing

1. **Test Public Function URL**
   ```bash
   curl $(terraform output -raw lambda_function_url)
   # Should succeed without authentication (ISSUE)
   ```

2. **View Plaintext Secrets**
   ```bash
   aws lambda get-function-configuration \
     --function-name $(terraform output -raw lambda_function_name) \
     --query 'Environment.Variables'
   # Should show plaintext secrets (ISSUE)
   ```

3. **Check IAM Permissions**
   ```bash
   aws iam list-attached-role-policies \
     --role-name devops-validation-lambda-problematic-role
   # Should show AdministratorAccess (ISSUE)
   ```

### Scenario 6 Testing

1. **Test IAM-Protected Function URL**
   ```bash
   curl $(terraform output -raw lambda_function_url)
   # Should fail with 403 Forbidden (CORRECT)
   ```

2. **Verify Secrets Manager Integration**
   ```bash
   aws lambda get-function-configuration \
     --function-name $(terraform output -raw lambda_function_name) \
     --query 'Environment.Variables'
   # Should only show SECRETS_ARN, not actual secrets (CORRECT)
   ```

3. **Check X-Ray Traces**
   ```bash
   aws xray get-trace-summaries \
     --start-time $(date -u -d '1 hour ago' +%s) \
     --end-time $(date -u +%s)
   # Should show traces (CORRECT)
   ```

## Recommendations

1. **Always use Scenario 6 patterns for production**
2. **Use Scenario 5 for training and security awareness**
3. **Implement automated scanning to detect Scenario 5 patterns**
4. **Use AWS Config rules to enforce Scenario 6 configurations**
5. **Regular security audits using DevOps Agent**

## Related Documentation

- [Scenario 5 README](../scenarios/05-ecr-lambda-problematic/README.md)
- [Scenario 6 README](../scenarios/06-ecr-lambda-improved/README.md)
- [AWS Lambda Security Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/lambda-security.html)
- [Amazon ECR Best Practices](https://docs.aws.amazon.com/AmazonECR/latest/userguide/best-practices.html)
