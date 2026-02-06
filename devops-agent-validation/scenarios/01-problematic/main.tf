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

  default_tags {
    tags = {
      Project     = "DevOps-Agent-Validation"
      Environment = "Problematic"
      ManagedBy   = "Terraform"
    }
  }
}

# ============================================
# ネットワーク観点の問題
# ============================================

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc-problematic"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-subnet-public"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-rt-public"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ============================================
# 問題1: セキュリティグループの過度な開放
# ============================================
resource "aws_security_group" "problematic_wide_open" {
  name        = "${var.project_name}-sg-wide-open"
  description = "ISSUE: Security group with overly permissive rules - ALL PORTS OPEN"
  vpc_id      = aws_vpc.main.id

  # 問題: すべてのTCPポートを0.0.0.0/0に開放
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "CRITICAL ISSUE: All TCP ports open to internet"
  }

  # 問題: すべてのUDPポートも開放
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "CRITICAL ISSUE: All UDP ports open to internet"
  }

  # 問題: ICMPも全開放
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "ISSUE: ICMP open to internet"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "${var.project_name}-sg-problematic"
    Issue = "overly-permissive-all-ports-open"
  }
}

# ============================================
# 問題2: NACLの設定ミス
# ============================================
resource "aws_network_acl" "problematic" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = [aws_subnet.public.id]

  # インバウンドは許可
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  # 問題: HTTPとHTTPSのアウトバウンドは許可
  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  egress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # 問題: エフェメラルポート（1024-65535）のアウトバウンドを拒否
  # これによりHTTPレスポンスが返せない
  egress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  tags = {
    Name  = "${var.project_name}-nacl-problematic"
    Issue = "nacl-blocks-ephemeral-ports-response-traffic-fails"
  }
}

# ============================================
# 問題3: VPCエンドポイント未設定
# ============================================
# 意図的にVPCエンドポイントを作成しない
# S3、SSM、CloudWatchへのアクセスがインターネット経由になる
# コスト増加、セキュリティリスク、レイテンシ増加

# ============================================
# サーバー観点の問題
# ============================================

# ============================================
# 問題1: IAMロール未設定
# ============================================
# 意図的にIAMロールを作成しない
# EC2インスタンスにIAMインスタンスプロファイルを付与しない
# アプリケーションで認証情報をハードコードする想定

# ============================================
# 問題2: 古いAMIとSSM管理の欠如
# ============================================
resource "aws_instance" "problematic" {
  # 問題: 最新ではなく古いAMIを使用（パッチ未適用）
  ami           = data.aws_ami.old_amazon_linux.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public.id

  vpc_security_group_ids = [aws_security_group.problematic_wide_open.id]

  # 問題: IAMインスタンスプロファイル未設定
  # iam_instance_profile = null

  # 問題3: 詳細モニタリング無効
  monitoring = false

  # ルートボリュームも暗号化なし
  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = false  # 問題: 暗号化無効
    delete_on_termination = true
  }

  # 問題: ユーザーデータで認証情報をハードコード
  user_data = base64encode(<<-EOF
    #!/bin/bash
    # ============================================
    # CRITICAL ISSUE: Hardcoded AWS Credentials
    # ============================================
    export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
    export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    export AWS_DEFAULT_REGION="${var.aws_region}"
    
    # ============================================
    # ISSUE: No SSM Agent configuration
    # ISSUE: No CloudWatch Agent installation
    # ISSUE: No security updates
    # ============================================
    
    # 基本的なWebサーバーのみインストール
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    
    # 問題を示すHTMLページ
    cat > /var/www/html/index.html << 'HTML'
    <!DOCTYPE html>
    <html>
    <head>
        <title>Problematic Server</title>
        <style>
            body { font-family: Arial; margin: 40px; background: #ffe6e6; }
            .issue { background: #ff4444; color: white; padding: 10px; margin: 10px 0; border-radius: 5px; }
            h1 { color: #cc0000; }
        </style>
    </head>
    <body>
        <h1>⚠️ Problematic Server - Multiple Security Issues</h1>
        <div class="issue">❌ Hardcoded AWS Credentials</div>
        <div class="issue">❌ No IAM Role</div>
        <div class="issue">❌ Old AMI (Unpatched)</div>
        <div class="issue">❌ No SSM Agent</div>
        <div class="issue">❌ No CloudWatch Monitoring</div>
        <div class="issue">❌ Security Group: All Ports Open</div>
        <div class="issue">❌ NACL: Misconfigured</div>
        <div class="issue">❌ No VPC Endpoints</div>
        <div class="issue">❌ No Encryption</div>
        <div class="issue">❌ No Backups</div>
    </body>
    </html>
HTML
    
    # ログに問題を記録
    echo "WARNING: This instance has multiple security issues" >> /var/log/security-issues.log
    echo "- Hardcoded credentials in user data" >> /var/log/security-issues.log
    echo "- No IAM role attached" >> /var/log/security-issues.log
    echo "- Old AMI without latest patches" >> /var/log/security-issues.log
  EOF
  )

  tags = {
    Name   = "${var.project_name}-ec2-problematic"
    Issues = "no-iam-role,old-ami,no-monitoring,hardcoded-credentials,no-ssm,no-encryption"
  }
}

# ============================================
# ストレージ観点の問題
# ============================================

# ============================================
# 問題1: S3バケットのパブリックアクセス許可
# ============================================
resource "aws_s3_bucket" "problematic" {
  bucket_prefix = "${var.project_name}-problematic-"

  tags = {
    Name  = "${var.project_name}-bucket-problematic"
    Issue = "public-access-enabled-no-versioning-no-encryption"
  }
}

# 問題: パブリックアクセスブロック未設定（すべてfalse）
resource "aws_s3_bucket_public_access_block" "problematic" {
  bucket = aws_s3_bucket.problematic.id

  block_public_acls       = false  # 問題: パブリックACL許可
  block_public_policy     = false  # 問題: パブリックポリシー許可
  ignore_public_acls      = false  # 問題: パブリックACL無視しない
  restrict_public_buckets = false  # 問題: パブリックバケット制限なし
}

# 問題: バージョニング無効（意図的に設定しない）
# 誤削除時に復旧不可

# 問題: 暗号化設定なし（意図的に設定しない）
# デフォルトでSSE-S3が有効だが、明示的な設定なし

# 問題: ライフサイクルポリシーなし
# 古いデータが残り続けてコスト増加

# サンプルファイルをアップロード（問題を示すため）
resource "aws_s3_object" "sample" {
  bucket  = aws_s3_bucket.problematic.id
  key     = "sample-data.txt"
  content = "This is a sample file in a bucket with security issues"

  # 問題: パブリック読み取り可能
  acl = "public-read"

  tags = {
    Issue = "public-readable-object"
  }
}

# ============================================
# 問題2: EBSボリューム暗号化無効
# ============================================
resource "aws_ebs_volume" "problematic" {
  availability_zone = data.aws_availability_zones.available.names[0]
  size              = 20
  type              = "gp3"

  # 問題: 暗号化無効
  encrypted = false

  tags = {
    Name  = "${var.project_name}-ebs-problematic"
    Issue = "encryption-disabled-data-at-rest-not-protected"
  }
}

resource "aws_volume_attachment" "problematic" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.problematic.id
  instance_id = aws_instance.problematic.id
}

# ============================================
# 問題3: バックアップ設定の欠如
# ============================================
# AWS Backupの設定なし（意図的に作成しない）
# スナップショットの自動作成なし
# データ損失時に復旧不可

# ============================================
# Data Sources
# ============================================

data "aws_availability_zones" "available" {
  state = "available"
}

# 問題: 古いAMIを意図的に使用
data "aws_ami" "old_amazon_linux" {
  most_recent = false
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.0.20230119.1-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_caller_identity" "current" {}