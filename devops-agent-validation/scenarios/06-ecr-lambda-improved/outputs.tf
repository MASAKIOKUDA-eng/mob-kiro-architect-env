output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.improved.repository_url
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.improved.function_name
}

output "lambda_function_url" {
  description = "Lambda function URL (IAM authenticated)"
  value       = aws_lambda_function_url.improved.function_url
}

output "lambda_alias" {
  description = "Lambda production alias"
  value       = aws_lambda_alias.improved_prod.name
}

output "secrets_manager_arn" {
  description = "Secrets Manager ARN for Lambda secrets"
  value       = aws_secretsmanager_secret.lambda_secrets.arn
}

output "dlq_url" {
  description = "Dead Letter Queue URL"
  value       = aws_sqs_queue.lambda_dlq.url
}

output "improvements_summary" {
  description = "Summary of improvements in this scenario"
  value = {
    ecr_improvements = [
      "Image scanning enabled on push",
      "Immutable image tags",
      "Lifecycle policy (keep last 10 tagged, remove untagged after 7 days)",
      "Repository policy with least privilege",
      "KMS encryption enabled"
    ]
    lambda_improvements = [
      "Secrets stored in AWS Secrets Manager",
      "Least privilege IAM role",
      "Dead letter queue configured",
      "X-Ray tracing enabled",
      "IAM authentication on function URL",
      "30-day CloudWatch Logs retention",
      "VPC configuration for network isolation",
      "Versioning and aliases for deployment",
      "Appropriate timeout (30s) and memory (512MB)",
      "Reserved concurrent executions for cost control",
      "CloudWatch alarms for errors and duration"
    ]
  }
}
