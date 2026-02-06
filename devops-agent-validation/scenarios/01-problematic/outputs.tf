output "issues_summary" {
  description = "Summary of all security and configuration issues"
  value = {
    network_issues = {
      security_group = "All ports (0-65535) open to 0.0.0.0/0"
      nacl           = "Ephemeral ports blocked - HTTP responses will fail"
      vpc_endpoints  = "Not configured - AWS service access via internet"
    }
    server_issues = {
      iam_role          = "No IAM role - hardcoded credentials in user data"
      ami               = "Old AMI (2023-01-19) - security patches missing"
      monitoring        = "Detailed monitoring disabled"
      ssm               = "SSM Agent not configured"
      cloudwatch_agent  = "CloudWatch Agent not installed"
      root_volume       = "Root volume not encrypted"
    }
    storage_issues = {
      s3_public_access = "Public access block disabled - data exposure risk"
      s3_versioning    = "Versioning disabled - cannot recover deleted objects"
      s3_encryption    = "No explicit encryption configuration"
      ebs_encryption   = "EBS volume not encrypted"
      backups          = "No backup configuration - data loss risk"
    }
  }
}

output "instance_public_ip" {
  description = "Public IP of the problematic EC2 instance"
  value       = aws_instance.problematic.public_ip
}

output "instance_id" {
  description = "ID of the problematic EC2 instance"
  value       = aws_instance.problematic.id
}

output "s3_bucket_name" {
  description = "Name of the problematic S3 bucket"
  value       = aws_s3_bucket.problematic.id
}

output "s3_public_url" {
  description = "Public URL of the sample file (demonstrates public access issue)"
  value       = "https://${aws_s3_bucket.problematic.bucket_regional_domain_name}/sample-data.txt"
}

output "ebs_volume_id" {
  description = "ID of the unencrypted EBS volume"
  value       = aws_ebs_volume.problematic.id
}

output "security_group_id" {
  description = "ID of the overly permissive security group"
  value       = aws_security_group.problematic_wide_open.id
}

output "web_url" {
  description = "URL to access the web server (may not work due to NACL issue)"
  value       = "http://${aws_instance.problematic.public_ip}"
}

output "validation_commands" {
  description = "Commands to validate the issues"
  value = {
    check_security_group = "aws ec2 describe-security-groups --group-ids ${aws_security_group.problematic_wide_open.id}"
    check_nacl           = "aws ec2 describe-network-acls --network-acl-ids ${aws_network_acl.problematic.id}"
    check_instance_role  = "aws ec2 describe-instances --instance-ids ${aws_instance.problematic.id} --query 'Reservations[0].Instances[0].IamInstanceProfile'"
    check_s3_public      = "aws s3api get-public-access-block --bucket ${aws_s3_bucket.problematic.id}"
    check_ebs_encryption = "aws ec2 describe-volumes --volume-ids ${aws_ebs_volume.problematic.id} --query 'Volumes[0].Encrypted'"
    test_web_access      = "curl -v http://${aws_instance.problematic.public_ip}"
  }
}

output "well_architected_violations" {
  description = "Well-Architected Framework violations"
  value = {
    operational_excellence = [
      "No SSM Agent configuration",
      "No CloudWatch Logs integration",
      "No automated patching"
    ]
    security = [
      "Overly permissive security group",
      "No IAM role (hardcoded credentials)",
      "No encryption at rest",
      "Public S3 access enabled"
    ]
    reliability = [
      "No backup configuration",
      "Single AZ deployment",
      "No versioning on S3"
    ]
    performance_efficiency = [
      "No detailed monitoring",
      "No performance metrics collection"
    ]
    cost_optimization = [
      "No VPC endpoints (unnecessary data transfer costs)",
      "No lifecycle policies on S3"
    ]
  }
}