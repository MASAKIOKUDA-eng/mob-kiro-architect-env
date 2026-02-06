variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "devops-validation"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "admin_cidr_blocks" {
  description = "CIDR blocks allowed for SSH access (admin IPs only)"
  type        = list(string)
  default     = ["10.0.0.0/8"]  # 本番環境では実際の管理IPに変更
}