output "web_server_url" {
  description = "URL of the web server"
  value       = "http://${aws_instance.web.public_ip}"
}

output "public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.web.public_ip
}