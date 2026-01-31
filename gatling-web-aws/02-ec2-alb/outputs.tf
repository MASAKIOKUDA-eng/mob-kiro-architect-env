output "alb_url" {
  description = "URL of the Application Load Balancer"
  value       = "http://${aws_lb.main.dns_name}"
}

output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = aws_lb.main.dns_name
}

output "ec2_instance_ips" {
  description = "Private IP addresses of EC2 instances"
  value       = aws_instance.web[*].private_ip
}

out
put "alb_logs_bucket" {
  description = "S3 bucket for ALB access logs"
  value       = aws_s3_bucket.alb_logs.id
}

output "cloudtrail_id" {
  description = "CloudTrail ID"
  value       = module.cloudtrail.cloudtrail_id
}

output "cloudwatch_dashboard" {
  description = "CloudWatch Dashboard name"
  value       = module.monitoring.dashboard_name
}

output "cloudwatch_log_groups" {
  description = "CloudWatch Log Groups"
  value = {
    application = module.monitoring.application_log_group_name
    system      = module.monitoring.system_log_group_name
    vpc_flow    = module.vpc_flow_logs.log_group_name
    cloudtrail  = module.cloudtrail.log_group_name
  }
}
