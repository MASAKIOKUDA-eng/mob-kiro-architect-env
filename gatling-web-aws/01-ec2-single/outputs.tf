output "web_server_url" {
  description = "URL of the web server"
  value       = "http://${aws_instance.web.public_ip}"
}

output "public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.web.public_ip
}

out
put "cloudtrail_id" {
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
