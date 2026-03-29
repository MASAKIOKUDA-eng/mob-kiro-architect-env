variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
  default     = "ami-0d52744d6551d851e"  # Amazon Linux 2023 AMI (ap-northeast-1)
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_pair_name" {
  description = "EC2 Key Pair name"
  type        = string
  default     = "my-key-pair"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}