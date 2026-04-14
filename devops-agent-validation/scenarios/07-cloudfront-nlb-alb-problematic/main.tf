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

# ===================================================================
# VPC・ネットワーク
# ===================================================================

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "cloudfront-nlb-alb-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "cloudfront-nlb-alb-igw" }
}

# Public Subnets
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = true
  tags                    = { Name = "public-subnet-1" }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-northeast-1c"
  map_public_ip_on_launch = true
  tags                    = { Name = "public-subnet-2" }
}

# Private Subnets
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "ap-northeast-1a"
  tags              = { Name = "private-subnet-1" }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "ap-northeast-1c"
  tags              = { Name = "private-subnet-2" }
}

resource "aws_subnet" "private_3" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "ap-northeast-1d"
  tags              = { Name = "private-subnet-3" }
}

# Route Table - Public
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "public-route-table" }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "nat-eip" }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id
  tags          = { Name = "main-nat-gateway" }
  depends_on    = [aws_internet_gateway.main]
}

# Route Table - Private
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
  tags = { Name = "private-route-table" }
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_3" {
  subnet_id      = aws_subnet.private_3.id
  route_table_id = aws_route_table.private.id
}

# ===================================================================
# 【設定ミス6】NACL - エフェメラルポートのアウトバウンド未許可
# ===================================================================
resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id, aws_subnet.private_3.id]

  # インバウンド：HTTP許可
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "10.0.0.0/16"
    from_port  = 80
    to_port    = 80
  }

  # インバウンド：NAT Gatewayからの戻りトラフィック
  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # 問題：エフェメラルポート(1024-65535)のアウトバウンドが未許可
  # HTTPレスポンスが返せない
  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  tags = { Name = "private-nacl" }
}

# ===================================================================
# Security Groups
# ===================================================================

# 【設定ミス2】ALB SG - SSH(22)を0.0.0.0/0に開放
resource "aws_security_group" "alb" {
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 問題：ALBにSSHは不要、かつ全IP開放
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "alb-security-group" }
}

resource "aws_security_group" "ec2" {
  description = "Security group for EC2 instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ec2-security-group" }
}

# ===================================================================
# Load Balancers
# ===================================================================

resource "aws_lb" "main" {
  name               = "cloudfront-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  enable_deletion_protection = false

  # ALBアクセスログ有効化
  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    prefix  = "alb"
    enabled = true
  }

  tags = { Name = "cloudfront-alb" }
}

# 【設定ミス3】NLB - internal=true でCloudFrontから到達不可
resource "aws_lb" "nlb" {
  name               = "cloudfront-nlb"
  internal           = true  # 問題：CloudFrontからアクセスできない
  load_balancer_type = "network"
  subnets            = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  enable_deletion_protection = false
  tags = { Name = "cloudfront-nlb" }
}

# Target Groups
resource "aws_lb_target_group" "alb_tg" {
  name     = "alb-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = { Name = "alb-target-group" }
}

# 【設定ミス4】NLB TG - 存在しないヘルスチェックパス
resource "aws_lb_target_group" "nlb_tg" {
  name     = "nlb-target-group"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    port                = "traffic-port"
    protocol            = "HTTP"
    path                = "/healthz"  # 問題：存在しないパス → 常にunhealthy
    unhealthy_threshold = 2
  }

  tags = { Name = "nlb-target-group" }
}

# Listeners
resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_tg.arn
  }
}

resource "aws_lb_listener" "nlb_listener" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_tg.arn
  }
}

# ===================================================================
# EC2 / ASG
# ===================================================================

# 【設定ミス1】キーペアなし → SSH接続不可
resource "aws_launch_template" "web" {
  name_prefix   = "web-server-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  # key_name 未設定 → SSHログイン不可

  vpc_security_group_ids = [aws_security_group.ec2.id]

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  user_data = base64encode(templatefile("${path.module}/user-data.sh", {}))

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "web-server" }
  }
}

# 【設定ミス7】ASG - grace_period=10s → 起動前にunhealthy判定で無限置き換え
resource "aws_autoscaling_group" "web" {
  name                      = "web-asg"
  vpc_zone_identifier       = [aws_subnet.private_1.id, aws_subnet.private_2.id, aws_subnet.private_3.id]
  target_group_arns         = [aws_lb_target_group.alb_tg.arn, aws_lb_target_group.nlb_tg.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 10  # 問題：短すぎる

  min_size         = 3
  max_size         = 3
  desired_capacity = 3

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "web-server-asg"
    propagate_at_launch = false
  }
}

# ===================================================================
# 【設定ミス5】CloudFront - http-only / allow-all / Cookie転送なし
# 【設定ミス8】Cookie・ヘッダー転送なし
# ===================================================================

resource "aws_cloudfront_distribution" "main" {
  origin {
    domain_name = aws_lb.main.dns_name
    origin_id   = "ALB-${aws_lb.main.name}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"  # 問題：HTTPSを使用していない
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront distribution for ALB"
  default_root_object = "index.html"

  # CloudFrontアクセスログ有効化
  logging_config {
    include_cookies = true
    bucket          = aws_s3_bucket.cloudfront_logs.bucket_regional_domain_name
    prefix          = "cloudfront/"
  }

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "ALB-${aws_lb.main.name}"

    forwarded_values {
      query_string = false
      # 【設定ミス8】Cookie/ヘッダー転送なし → セッション管理不可
      headers = []
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"  # 問題：HTTPSを強制していない
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = { Name = "cloudfront-distribution" }
}

# ===================================================================
# ログ・モニタリング設定
# 各設定ミスの障害を検知・可視化するためのリソース
# ===================================================================

# -------------------------------------------------------------------
# VPC Flow Logs → CloudWatch Logs
# 設定ミス6(NACL)によるREJECTトラフィックを記録
# -------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/vpc/cloudfront-nlb-alb-flow-logs"
  retention_in_days = 14
  tags              = { Name = "vpc-flow-logs" }
}

resource "aws_iam_role" "vpc_flow_logs" {
  name = "vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Effect   = "Allow"
      Resource = "*"
    }]
  })
}

resource "aws_flow_log" "vpc" {
  vpc_id                   = aws_vpc.main.id
  traffic_type             = "ALL"
  log_destination          = aws_cloudwatch_log_group.vpc_flow_logs.arn
  iam_role_arn             = aws_iam_role.vpc_flow_logs.arn
  max_aggregation_interval = 60

  tags = { Name = "vpc-flow-log" }
}

# -------------------------------------------------------------------
# ALB アクセスログ用 S3 バケット
# 設定ミス2(SG開放)、ミス6(NACL)による異常トラフィックを記録
# -------------------------------------------------------------------
resource "aws_s3_bucket" "alb_logs" {
  bucket_prefix = "cloudfront-alb-logs-"
  force_destroy = true
  tags          = { Name = "alb-access-logs" }
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { AWS = data.aws_elb_service_account.main.arn }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.alb_logs.arn}/alb/*"
      },
      {
        Effect    = "Allow"
        Principal = { Service = "delivery.logs.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.alb_logs.arn}/alb/*"
        Condition = { StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" } }
      },
      {
        Effect    = "Allow"
        Principal = { Service = "delivery.logs.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.alb_logs.arn
      }
    ]
  })
}

# -------------------------------------------------------------------
# CloudFront アクセスログ用 S3 バケット
# 設定ミス5(http-only)、ミス8(Cookie転送なし)の影響を記録
# -------------------------------------------------------------------
resource "aws_s3_bucket" "cloudfront_logs" {
  bucket_prefix = "cloudfront-dist-logs-"
  force_destroy = true
  tags          = { Name = "cloudfront-access-logs" }
}

resource "aws_s3_bucket_ownership_controls" "cloudfront_logs" {
  bucket = aws_s3_bucket.cloudfront_logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "cloudfront_logs" {
  depends_on = [aws_s3_bucket_ownership_controls.cloudfront_logs]
  bucket     = aws_s3_bucket.cloudfront_logs.id
  acl        = "log-delivery-write"
}

# -------------------------------------------------------------------
# CloudWatch メトリクスフィルター & アラーム
# VPC Flow LogsからREJECTされたトラフィックを検知
# -------------------------------------------------------------------
resource "aws_cloudwatch_log_metric_filter" "rejected_traffic" {
  name           = "rejected-traffic-filter"
  pattern        = "REJECT"
  log_group_name = aws_cloudwatch_log_group.vpc_flow_logs.name

  metric_transformation {
    name          = "RejectedPacketCount"
    namespace     = "CustomVPCMetrics"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_sns_topic" "alerts" {
  name = "network-alerts"
  tags = { Name = "network-alerts" }
}

resource "aws_cloudwatch_metric_alarm" "rejected_traffic" {
  alarm_name          = "high-rejected-traffic"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RejectedPacketCount"
  namespace           = "CustomVPCMetrics"
  period              = 300
  statistic           = "Sum"
  threshold           = 100
  alarm_description   = "VPC Flow LogsでREJECTされたパケットが多数検出 - NACLまたはSG設定を確認"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  tags = { Name = "rejected-traffic-alarm" }
}

# -------------------------------------------------------------------
# ALB ターゲットヘルスチェック失敗アラーム
# 設定ミス4(NLBヘルスチェック)、ミス7(grace period)を検知
# -------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "alb-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "ALBターゲットにunhealthyホストが存在 - ヘルスチェック設定またはNACLを確認"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    TargetGroup  = aws_lb_target_group.alb_tg.arn_suffix
    LoadBalancer = aws_lb.main.arn_suffix
  }

  tags = { Name = "alb-unhealthy-alarm" }
}

resource "aws_cloudwatch_metric_alarm" "nlb_unhealthy_hosts" {
  alarm_name          = "nlb-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/NetworkELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "NLBターゲットにunhealthyホストが存在 - /healthz パスの存在とヘルスチェック設定を確認"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    TargetGroup  = aws_lb_target_group.nlb_tg.arn_suffix
    LoadBalancer = aws_lb.nlb.arn_suffix
  }

  tags = { Name = "nlb-unhealthy-alarm" }
}

# -------------------------------------------------------------------
# ASG インスタンス置き換え頻度アラーム
# 設定ミス7(grace_period短すぎ)による無限置き換えを検知
# -------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "asg_terminations" {
  alarm_name          = "asg-frequent-terminations"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "GroupTerminatingInstances"
  namespace           = "AWS/AutoScaling"
  period              = 300
  statistic           = "Sum"
  threshold           = 2
  alarm_description   = "ASGで頻繁なインスタンス終了を検出 - health_check_grace_period が短すぎる可能性"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }

  tags = { Name = "asg-termination-alarm" }
}

# -------------------------------------------------------------------
# CloudFront 4xx/5xx エラー率アラーム
# 設定ミス3(internal NLB)、ミス5(http-only)の影響を検知
# -------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "cloudfront_5xx" {
  alarm_name          = "cloudfront-high-5xx-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "5xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = 300
  statistic           = "Average"
  threshold           = 5
  alarm_description   = "CloudFrontで5xxエラー率が高い - オリジン接続設定(http-only)またはALB/NLBの状態を確認"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DistributionId = aws_cloudfront_distribution.main.id
    Region         = "Global"
  }

  tags = { Name = "cloudfront-5xx-alarm" }
}

resource "aws_cloudwatch_metric_alarm" "cloudfront_4xx" {
  alarm_name          = "cloudfront-high-4xx-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "4xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = 300
  statistic           = "Average"
  threshold           = 10
  alarm_description   = "CloudFrontで4xxエラー率が高い - Cookie/ヘッダー転送設定を確認"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DistributionId = aws_cloudfront_distribution.main.id
    Region         = "Global"
  }

  tags = { Name = "cloudfront-4xx-alarm" }
}
