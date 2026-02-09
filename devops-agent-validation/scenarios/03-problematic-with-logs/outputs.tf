output "issues_summary" {
  description = "Summary of all security and configuration issues (same as Scenario 1)"
  value = {
    network_issues = {
      security_group = "All ports (0-65535) open to 0.0.0.0/0"
      nacl           = "Ephemeral ports blocked - HTTP responses will fail"
      vpc_endpoints  = "Not configured - AWS service access via internet"
    }
    server_issues = {
      iam_role_note     = "IAM role attached BUT only for logging - still has hardcoded credentials"
      ami               = "Using Amazon Linux 2 (in production, using old AMI versions is a security risk)"
      monitoring        = "Detailed monitoring ENABLED (for comparison)"
      cloudwatch_agent  = "CloudWatch Agent INSTALLED (for logging)"
      root_volume       = "Root volume not encrypted"
    }
    storage_issues = {
      s3_public_access = "Public access block disabled - data exposure risk"
      s3_versioning    = "Versioning disabled - cannot recover deleted objects"
      s3_encryption    = "No explicit encryption configuration"
      ebs_encryption   = "EBS volume not encrypted"
      backups          = "No backup configuration - data loss risk"
    }
    logging_status = {
      cloudwatch_logs = "ENABLED - Application and system logs collected"
      vpc_flow_logs   = "ENABLED - Network traffic logged"
      detailed_monitoring = "ENABLED - Enhanced metrics available"
    }
  }
}

output "instance_public_ip" {
  description = "Public IP of the problematic EC2 instance (with logs)"
  value       = aws_instance.problematic_with_logs.public_ip
}

output "instance_id" {
  description = "ID of the problematic EC2 instance (with logs)"
  value       = aws_instance.problematic_with_logs.id
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
  value       = "http://${aws_instance.problematic_with_logs.public_ip}"
}

output "cloudwatch_log_groups" {
  description = "CloudWatch Log Groups for troubleshooting"
  value = {
    application    = aws_cloudwatch_log_group.application.name
    system         = aws_cloudwatch_log_group.system.name
    vpc_flow_logs  = aws_cloudwatch_log_group.vpc_flow_logs.name
  }
}

output "log_insights_queries" {
  description = "CloudWatch Logs Insights queries for analysis"
  value = {
    view_application_logs = "aws logs tail ${aws_cloudwatch_log_group.application.name} --follow"
    view_system_logs      = "aws logs tail ${aws_cloudwatch_log_group.system.name} --follow"
    view_vpc_flow_logs    = "aws logs tail ${aws_cloudwatch_log_group.vpc_flow_logs.name} --follow"
    
    query_rejected_traffic = <<-EOT
      fields @timestamp, srcAddr, dstAddr, dstPort, action
      | filter action = "REJECT"
      | sort @timestamp desc
      | limit 20
    EOT
    
    query_security_issues = <<-EOT
      fields @timestamp, @message
      | filter @message like /WARNING|ERROR|security/
      | sort @timestamp desc
    EOT
  }
}

output "validation_commands" {
  description = "Commands to validate the issues and logs"
  value = {
    check_security_group = "aws ec2 describe-security-groups --group-ids ${aws_security_group.problematic_wide_open.id}"
    check_nacl           = "aws ec2 describe-network-acls --network-acl-ids ${aws_network_acl.problematic.id}"
    check_instance_role  = "aws ec2 describe-instances --instance-ids ${aws_instance.problematic_with_logs.id} --query 'Reservations[0].Instances[0].IamInstanceProfile'"
    check_s3_public      = "aws s3api get-public-access-block --bucket ${aws_s3_bucket.problematic.id}"
    check_ebs_encryption = "aws ec2 describe-volumes --volume-ids ${aws_ebs_volume.problematic.id} --query 'Volumes[0].Encrypted'"
    test_web_access      = "curl -v http://${aws_instance.problematic_with_logs.public_ip}"
    
    # ログ確認コマンド
    view_application_logs = "aws logs tail ${aws_cloudwatch_log_group.application.name} --follow"
    view_vpc_flow_logs    = "aws logs tail ${aws_cloudwatch_log_group.vpc_flow_logs.name} --follow"
    check_cloudwatch_metrics = "aws cloudwatch get-metric-statistics --namespace ${var.project_name}-s3/EC2 --metric-name cpu_usage_idle --dimensions Name=InstanceId,Value=${aws_instance.problematic_with_logs.id} --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 300 --statistics Average"
  }
}

output "comparison_with_scenario_1" {
  description = "Key differences from Scenario 1"
  value = {
    same_security_issues = "Yes - All security problems from Scenario 1 are present"
    logging_enabled      = "Yes - CloudWatch Logs and VPC Flow Logs are enabled"
    monitoring_enabled   = "Yes - Detailed monitoring is enabled"
    
    advantages = [
      "Can identify security issues through logs",
      "Can trace network traffic with VPC Flow Logs",
      "Can monitor performance metrics",
      "Can troubleshoot problems faster"
    ]
    
    disadvantages = [
      "Higher cost (~$11/month more)",
      "Security issues still exist",
      "Logs show the problems but don't prevent them"
    ]
  }
}

output "cost_estimate" {
  description = "Estimated monthly cost"
  value = {
    ec2                     = "$8"
    ebs                     = "$2"
    s3                      = "$1"
    cloudwatch_logs         = "$5"
    vpc_flow_logs           = "$3"
    detailed_monitoring     = "$3"
    total                   = "$22/month"
    difference_from_s1      = "+$11/month (logging overhead)"
  }
}