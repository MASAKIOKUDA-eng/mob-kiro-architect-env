output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.problematic.repository_url
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.problematic.function_name
}

output "lambda_function_url" {
  description = "Lambda function URL (publicly accessible)"
  value       = aws_lambda_function_url.problematic.function_url
}

output "issues_summary" {
  description = "Summary of issues in this scenario"
  value = {
    ecr_issues = [
      "Image scanning disabled",
      "Mutable image tags",
      "No lifecycle policy",
      "Repository policy allows all AWS accounts",
      "No encryption configuration"
    ]
    lambda_issues = [
      "Plaintext secrets in environment variables",
      "Excessive IAM permissions (AdministratorAccess)",
      "No dead letter queue",
      "No X-Ray tracing",
      "Public function URL without authentication",
      "Unlimited CloudWatch Logs retention",
      "No VPC configuration",
      "No versioning or aliases",
      "Excessive timeout (900s)",
      "Excessive memory (10GB)"
    ]
  }
}
