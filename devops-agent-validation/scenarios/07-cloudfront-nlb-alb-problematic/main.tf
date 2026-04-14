# CloudFront + NLB + ALB + EC2 構成（8つのネットワーク・運用設定ミスを含む）
# すべて terraform apply は成功するが、実運用で問題が発生するパターン
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}
data "aws_elb_service_account" "main" {}

# =============================================================================
# VPC・ネットワーク
# =============================================================================

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "cloudfront-nlb-alb-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "cloudfront-nlb-alb-igw"
  }
}

# Public Subnets
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = true

  tags = { Name = "public-subnet-1" }
}
