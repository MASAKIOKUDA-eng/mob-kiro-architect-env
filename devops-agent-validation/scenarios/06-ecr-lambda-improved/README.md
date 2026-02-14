# Scenario 6: ECR and Lambda - Improved Configuration

## Overview

This scenario demonstrates best practices for Amazon ECR and AWS Lambda following AWS Well-Architected Framework principles.

## Improvements Implemented

### ECR Improvements (5 improvements)

1. **Image Scanning Enabled**
   - Automatically scans images on push for vulnerabilities
   - Well-Architected Pillar: Security
   - Benefit: Early detection of security issues

2. **Immutable Image Tags**
   - Tags cannot be overwritten
   - Well-Architected Pillar: Operational Excellence
   - Benefit: Deployment reproducibility and traceability

3. **Lifecycle Policy**
   - Keeps last 10 tagged images
   - Removes untagged images after 7 days
   - Well-Architected Pillar: Cost Optimization
   - Benefit: Automatic cleanup, reduced storage costs

4. **Least Privilege Repository Policy**
   - Only specific Lambda role can pull images
   - Well-Architected Pillar: Security
   - Benefit: Prevents unauthorized access

5. **KMS Encryption**
   - Images encrypted with customer-managed keys
   - Well-Architected Pillar: Security
   - Benefit: Enhanced data protection and compliance

### Lambda Improvements (11 improvements)

1. **Secrets Manager Integration**
   - Secrets stored in AWS Secrets Manager
   - Well-Architected Pillar: Security
   - Benefit: Encrypted secrets with rotation capability

2. **Least Privilege IAM Role**
   - Only necessary permissions granted
   - Well-Architected Pillar: Security
   - Benefit: Reduced blast radius of potential compromise

3. **Dead Letter Queue**
   - Failed invocations sent to SQS DLQ
   - Well-Architected Pillar: Reliability
   - Benefit: No data loss, easier debugging

4. **X-Ray Tracing**
   - Active tracing enabled
   - Well-Architected Pillar: Operational Excellence
   - Benefit: Better observability and debugging

5. **IAM Authentication on Function URL**
   - Requires AWS IAM credentials
   - Well-Architected Pillar: Security
   - Benefit: Prevents unauthorized access

6. **CloudWatch Logs Retention**
   - 30-day retention policy
   - Well-Architected Pillar: Cost Optimization
   - Benefit: Balanced between observability and cost

7. **VPC Configuration**
   - Lambda runs in private subnets
   - Well-Architected Pillar: Security
   - Benefit: Network isolation and access to private resources

8. **Versioning and Aliases**
   - Production alias for stable deployments
   - Well-Architected Pillar: Operational Excellence
   - Benefit: Easy rollback and blue/green deployments

9. **Appropriate Timeout (30s)**
   - Reasonable timeout setting
   - Well-Architected Pillar: Cost Optimization
   - Benefit: Prevents runaway functions

10. **Appropriate Memory (512MB)**
    - Right-sized memory allocation
    - Well-Architected Pillar: Cost Optimization
    - Benefit: Cost-effective performance

11. **Reserved Concurrent Executions**
    - Limited to 10 concurrent executions
    - Well-Architected Pillar: Cost Optimization
    - Benefit: Cost control and predictability

12. **CloudWatch Alarms**
    - Alarms for errors and duration
    - Well-Architected Pillar: Operational Excellence
    - Benefit: Proactive monitoring and alerting

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         VPC (10.1.0.0/16)                   │
│                                                             │
│  ┌──────────────────┐         ┌──────────────────┐        │
│  │ Private Subnet 1 │         │ Private Subnet 2 │        │
│  │   10.1.1.0/24    │         │   10.1.2.0/24    │        │
│  │                  │         │                  │        │
│  │  ┌────────────┐  │         │                  │        │
│  │  │  Lambda    │  │         │                  │        │
│  │  │  Function  │  │         │                  │        │
│  │  └────────────┘  │         │                  │        │
│  └──────────────────┘         └──────────────────┘        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ Pulls images
                          ▼
                  ┌──────────────┐
                  │     ECR      │
                  │  Repository  │
                  │ (KMS Encrypted)│
                  └──────────────┘
                          │
                          │ Retrieves secrets
                          ▼
                  ┌──────────────┐
                  │   Secrets    │
                  │   Manager    │
                  └──────────────┘
```

## Deployment

### Prerequisites

Before deploying, you need to push a Docker image to ECR:

```bash
cd scenarios/06-ecr-lambda-improved
terraform init
terraform apply -target=aws_ecr_repository.improved

# Build and push a sample image
cat > Dockerfile << 'EOF'
FROM public.ecr.aws/lambda/python:3.11
COPY app.py ${LAMBDA_TASK_ROOT}
CMD [ "app.handler" ]
EOF

cat > app.py << 'EOF'
import json
import boto3
import os

def handler(event, context):
    # Retrieve secrets from Secrets Manager
    secrets_arn = os.environ.get('SECRETS_ARN')
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Hello from improved Lambda!',
            'environment': os.environ.get('ENVIRONMENT')
        })
    }
EOF

# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $(terraform output -raw ecr_repository_url | cut -d'/' -f1)

# Build and push
docker build -t devops-validation-improved-repo .
docker tag devops-validation-improved-repo:latest $(terraform output -raw ecr_repository_url):latest
docker push $(terraform output -raw ecr_repository_url):latest

# Deploy remaining resources
terraform apply
```

## Testing Improvements

### Test IAM Authentication
```bash
# Try to access without credentials (should fail)
curl $(terraform output -raw lambda_function_url)

# Access with AWS credentials (should succeed)
aws lambda invoke --function-name $(terraform output -raw lambda_function_name) response.json
cat response.json
```

### Check Secrets Manager Integration
```bash
# Verify secrets are not in environment variables
aws lambda get-function-configuration --function-name $(terraform output -raw lambda_function_name) --query 'Environment.Variables'
```

### Monitor with X-Ray
```bash
# View traces in X-Ray console
aws xray get-trace-summaries --start-time $(date -u -d '1 hour ago' +%s) --end-time $(date -u +%s)
```

### Check CloudWatch Alarms
```bash
# List alarms
aws cloudwatch describe-alarms --alarm-name-prefix devops-validation-lambda
```

## Cost Estimate

- ECR: ~$1/month (minimal storage with lifecycle policy)
- Lambda: ~$5-30/month (depending on invocations, optimized memory)
- CloudWatch Logs: ~$2-5/month (30-day retention)
- Secrets Manager: ~$0.40/month (1 secret)
- KMS: ~$1/month (1 key)
- VPC: ~$0/month (no NAT Gateway in this example)
- X-Ray: ~$0.50-2/month (depending on traces)
- **Total**: ~$10-40/month

**Savings vs Scenario 5**: ~$1-31/month (through optimization and lifecycle policies)

## Cleanup

```bash
# Delete all images from ECR first
aws ecr batch-delete-image --repository-name devops-validation-improved-repo --image-ids imageTag=latest

terraform destroy
```

## Comparison with Scenario 5

| Feature | Scenario 5 (Problematic) | Scenario 6 (Improved) |
|---------|-------------------------|----------------------|
| ECR Image Scanning | ❌ Disabled | ✅ Enabled |
| Image Tag Mutability | ❌ Mutable | ✅ Immutable |
| ECR Lifecycle Policy | ❌ None | ✅ Configured |
| ECR Repository Policy | ❌ Public (*) | ✅ Least Privilege |
| ECR Encryption | ❌ Default | ✅ KMS |
| Lambda Secrets | ❌ Plaintext | ✅ Secrets Manager |
| Lambda IAM Role | ❌ Admin Access | ✅ Least Privilege |
| Dead Letter Queue | ❌ None | ✅ SQS DLQ |
| X-Ray Tracing | ❌ Disabled | ✅ Active |
| Function URL Auth | ❌ None | ✅ IAM |
| Log Retention | ❌ Unlimited | ✅ 30 days |
| VPC Configuration | ❌ None | ✅ Private Subnets |
| Versioning | ❌ None | ✅ Aliases |
| Timeout | ❌ 900s | ✅ 30s |
| Memory | ❌ 10GB | ✅ 512MB |
| Concurrent Executions | ❌ Unlimited | ✅ Reserved (10) |
| CloudWatch Alarms | ❌ None | ✅ Configured |

## Related Scenarios

- **Scenario 5**: Problematic ECR and Lambda configuration
