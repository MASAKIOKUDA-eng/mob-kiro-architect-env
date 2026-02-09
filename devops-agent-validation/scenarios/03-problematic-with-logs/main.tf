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

# S3バケット所有権設定（ACLを使用するため）
resource "aws_s3_bucket_ownership_controls" "problematic" {
  bucket = aws_s3_bucket.problematic.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# バケットレベルのACL設定
resource "aws_s3_bucket_acl" "problematic" {
  depends_on = [aws_s3_bucket_ownership_controls.problematic]
  
  bucket = aws_s3_bucket.problematic.id
  acl    = "public-read"
}

# 問題: バージョニング無効（意図的に設定しない）
# 誤削除時に復旧不可

# 問題: 暗号化設定なし（意図的に設定しない）
# デフォルトでSSE-S3が有効だが、明示的な設定なし

# 問題: ライフサイクルポリシーなし
# 古いデータが残り続けてコスト増加

# サンプルファイルをアップロード（問題を示すため）
resource "aws_s3_object" "sample" {
  depends_on = [
    aws_s3_bucket_acl.problematic
  ]
  
  bucket  = aws_s3_bucket.problematic.id
  key     = "sample-data.txt"
  content = "This is a sample file in a bucket with security issues"

  # 問題: パブリック読み取り可能（バケットレベルのACLで設定）
  # acl = "public-read"  # オブジェクトレベルのACLは削除

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

# 問題: パッチ未適用のAMIを使用（検証用に最新のAL2を使用するが、本来は古いバージョンを使うべきでない）
# 実環境では特定の古いバージョンを指定することで脆弱性が残る
data "aws_ami" "old_amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  
  filter {
    name   = "state"
    values = ["available"]
  }
  
  # 注: 検証環境では最新のAL2を使用
  # 実際の問題シナリオでは、古い特定バージョンを指定することで
  # セキュリティパッチが適用されていない状態を再現
}

data "aws_caller_identity" "current" {}


# ============================================
# ログ出力の追加（シナリオ3用）
# ============================================

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/${var.project_name}-s3/application"
  retention_in_days = 7

  tags = {
    Name     = "${var.project_name}-s3-log-group"
    Scenario = "03-problematic-with-logs"
  }
}

resource "aws_cloudwatch_log_group" "system" {
  name              = "/aws/${var.project_name}-s3/system"
  retention_in_days = 7

  tags = {
    Name     = "${var.project_name}-s3-system-log-group"
    Scenario = "03-problematic-with-logs"
  }
}

# VPCフローログ用CloudWatch Log Group
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/${var.project_name}-s3/flow-logs"
  retention_in_days = 7

  tags = {
    Name     = "${var.project_name}-s3-vpc-flow-logs"
    Scenario = "03-problematic-with-logs"
  }
}

# VPCフローログ用IAMロール
resource "aws_iam_role" "vpc_flow_logs" {
  name = "${var.project_name}-s3-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name     = "${var.project_name}-s3-vpc-flow-logs-role"
    Scenario = "03-problematic-with-logs"
  }
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "${var.project_name}-s3-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

# VPCフローログ
resource "aws_flow_log" "main" {
  vpc_id          = aws_vpc.main.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn

  tags = {
    Name     = "${var.project_name}-s3-vpc-flow-log"
    Scenario = "03-problematic-with-logs"
  }
}

# CloudWatch Agentインストール用のIAMロール（問題のある環境でもログ収集のため）
resource "aws_iam_role" "ec2_cloudwatch_logs" {
  name = "${var.project_name}-s3-ec2-cloudwatch-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name     = "${var.project_name}-s3-ec2-cloudwatch-logs-role"
    Scenario = "03-problematic-with-logs"
  }
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent_server_policy" {
  role       = aws_iam_role.ec2_cloudwatch_logs.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_cloudwatch_logs" {
  name = "${var.project_name}-s3-ec2-cloudwatch-logs-profile"
  role = aws_iam_role.ec2_cloudwatch_logs.name
}

# EC2インスタンスを更新（IAMロールとモニタリング追加）
resource "aws_instance" "problematic_with_logs" {
  ami           = data.aws_ami.old_amazon_linux.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public.id

  vpc_security_group_ids = [aws_security_group.problematic_wide_open.id]

  # ログ収集のためIAMロールを追加
  iam_instance_profile = aws_iam_instance_profile.ec2_cloudwatch_logs.name

  # 詳細モニタリング有効化
  monitoring = true

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = false  # 問題: 暗号化無効（そのまま）
    delete_on_termination = true
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    # 問題のある設定はそのまま
    export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
    export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    
    # CloudWatch Agentのインストール（ログ収集のため）
    dnf install -y amazon-cloudwatch-agent
    
    # CloudWatch Agent設定
    cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json << 'CW_CONFIG'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/httpd/access_log",
            "log_group_name": "/aws/${var.project_name}-s3/application",
            "log_stream_name": "{instance_id}/httpd/access",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/httpd/error_log",
            "log_group_name": "/aws/${var.project_name}-s3/application",
            "log_stream_name": "{instance_id}/httpd/error",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/aws/${var.project_name}-s3/system",
            "log_stream_name": "{instance_id}/messages",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/security-issues.log",
            "log_group_name": "/aws/${var.project_name}-s3/system",
            "log_stream_name": "{instance_id}/security-issues",
            "timezone": "UTC"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "${var.project_name}-s3/EC2",
    "metrics_collected": {
      "cpu": {
        "measurement": [{"name": "cpu_usage_idle"}],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [{"name": "used_percent"}],
        "metrics_collection_interval": 60,
        "resources": ["*"]
      },
      "mem": {
        "measurement": [{"name": "mem_used_percent"}],
        "metrics_collection_interval": 60
      }
    }
  }
}
CW_CONFIG
    
    # CloudWatch Agent起動
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config \
      -m ec2 \
      -s \
      -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json
    
    # Webサーバーインストール
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    
    # HTMLページ
    cat > /var/www/html/index.html << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>Problematic Server with Logs</title>
    <style>
        body { font-family: Arial; margin: 40px; background: #fff3cd; }
        .issue { background: #ff4444; color: white; padding: 10px; margin: 10px 0; border-radius: 5px; }
        .log-enabled { background: #44ff44; color: #004400; padding: 10px; margin: 10px 0; border-radius: 5px; }
        h1 { color: #cc0000; }
    </style>
</head>
<body>
    <h1>⚠️ Problematic Server with Logs (Scenario 3)</h1>
    <h2>セキュリティ問題（シナリオ1と同じ）</h2>
    <div class="issue">❌ Hardcoded AWS Credentials</div>
    <div class="issue">❌ Security Group: All Ports Open</div>
    <div class="issue">❌ NACL: Misconfigured</div>
    <div class="issue">❌ No VPC Endpoints</div>
    <div class="issue">❌ No Encryption</div>
    <div class="issue">❌ No Backups</div>
    
    <h2>ログ出力（シナリオ3で追加）</h2>
    <div class="log-enabled">✅ CloudWatch Logs: 有効</div>
    <div class="log-enabled">✅ VPC Flow Logs: 有効</div>
    <div class="log-enabled">✅ 詳細モニタリング: 有効</div>
    
    <p><strong>検証ポイント:</strong> セキュリティ問題があってもログがあれば問題を特定しやすい</p>
</body>
</html>
HTML
    
    # セキュリティ問題をログに記録
    echo "WARNING: Multiple security issues detected" >> /var/log/security-issues.log
    echo "- Hardcoded credentials in user data" >> /var/log/security-issues.log
    echo "- Security group allows all ports" >> /var/log/security-issues.log
    echo "- NACL misconfigured" >> /var/log/security-issues.log
  EOF
  )

  tags = {
    Name     = "${var.project_name}-ec2-s3-problematic-with-logs"
    Scenario = "03-problematic-with-logs"
    Issues   = "same-as-scenario-1-but-with-logging"
  }
  
  # 元のインスタンスと競合しないように
  lifecycle {
    create_before_destroy = false
  }
}

# 元のインスタンスを削除（シナリオ3では新しいインスタンスを使用）
# resource "aws_instance" "problematic" を無効化するため、別名で作成