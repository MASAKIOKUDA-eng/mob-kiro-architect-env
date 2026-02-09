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
      Environment = "Improved"
      ManagedBy   = "Terraform"
    }
  }
}

# ============================================
# ネットワーク観点の改善
# ============================================

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc-improved"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Public Subnets (Multi-AZ)
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.1.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-subnet-public-${count.index + 1}"
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
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ============================================
# 改善1: 適切なセキュリティグループ設定
# ============================================
resource "aws_security_group" "improved_web" {
  name        = "${var.project_name}-sg-web-improved"
  description = "IMPROVED: Security group with least privilege principle"
  vpc_id      = aws_vpc.main.id

  # 改善: HTTP/HTTPSのみ許可
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from internet"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from internet"
  }

  # 改善: SSHは特定のIPのみ許可（管理用）
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
    description = "SSH from admin IPs only"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name        = "${var.project_name}-sg-improved"
    Improvement = "least-privilege-principle"
  }
}

# ============================================
# 改善2: 正しいNACL設定
# ============================================
resource "aws_network_acl" "improved" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.public[*].id

  # インバウンド: HTTP/HTTPS許可
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

  # インバウンド: エフェメラルポート許可（レスポンス用）
  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # アウトバウンド: HTTP/HTTPS許可
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

  # 改善: エフェメラルポート許可（レスポンス返却用）
  egress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  tags = {
    Name        = "${var.project_name}-nacl-improved"
    Improvement = "ephemeral-ports-allowed"
  }
}

# ============================================
# 改善3: VPCエンドポイント設定
# ============================================

# S3 VPCエンドポイント（Gateway型）
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.public.id]

  tags = {
    Name        = "${var.project_name}-vpce-s3"
    Improvement = "private-s3-access"
  }
}

# SSM VPCエンドポイント（Interface型）
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.public[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project_name}-vpce-ssm"
    Improvement = "private-ssm-access"
  }
}

# SSM Messages VPCエンドポイント
resource "aws_vpc_endpoint" "ssm_messages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.public[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project_name}-vpce-ssm-messages"
    Improvement = "private-ssm-messages-access"
  }
}

# EC2 Messages VPCエンドポイント
resource "aws_vpc_endpoint" "ec2_messages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.public[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project_name}-vpce-ec2-messages"
    Improvement = "private-ec2-messages-access"
  }
}

# CloudWatch Logs VPCエンドポイント
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.public[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project_name}-vpce-logs"
    Improvement = "private-cloudwatch-logs-access"
  }
}

# VPCエンドポイント用セキュリティグループ
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.project_name}-sg-vpc-endpoints"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
    description = "HTTPS from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg-vpc-endpoints"
  }
}

# ============================================
# サーバー観点の改善
# ============================================

# ============================================
# 改善1: IAMロール設定
# ============================================
resource "aws_iam_role" "ec2_improved" {
  name = "${var.project_name}-ec2-improved-role"

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
    Name        = "${var.project_name}-ec2-role"
    Improvement = "iam-role-instead-of-hardcoded-credentials"
  }
}

# SSM管理用ポリシーをアタッチ
resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.ec2_improved.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CloudWatch Agent用ポリシーをアタッチ
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2_improved.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# S3読み取り専用アクセス（必要に応じて）
resource "aws_iam_role_policy" "s3_read" {
  name = "${var.project_name}-s3-read-policy"
  role = aws_iam_role.ec2_improved.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.improved.arn,
          "${aws_s3_bucket.improved.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_improved" {
  name = "${var.project_name}-ec2-improved-profile"
  role = aws_iam_role.ec2_improved.name
}

# ============================================
# 改善2: 最新AMIとSSM管理
# ============================================
resource "aws_instance" "improved" {
  # 改善: 最新のAMIを使用
  ami           = data.aws_ami.latest_amazon_linux.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public[0].id

  vpc_security_group_ids = [aws_security_group.improved_web.id]

  # 改善: IAMインスタンスプロファイル設定
  iam_instance_profile = aws_iam_instance_profile.ec2_improved.name

  # 改善3: 詳細モニタリング有効
  monitoring = true

  # ルートボリュームの暗号化
  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true  # 改善: 暗号化有効
    delete_on_termination = true

    tags = {
      Name        = "${var.project_name}-root-volume"
      Improvement = "encrypted-root-volume"
    }
  }

  # 改善: セキュアなユーザーデータ
  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    project_name = var.project_name
    aws_region   = var.aws_region
  }))

  tags = {
    Name         = "${var.project_name}-ec2-improved"
    Improvements = "iam-role,latest-ami,monitoring,ssm,cloudwatch,encryption"
  }
}

# ============================================
# ストレージ観点の改善
# ============================================

# ============================================
# 改善1: セキュアなS3バケット設定
# ============================================
resource "aws_s3_bucket" "improved" {
  bucket_prefix = "${var.project_name}-improved-"

  tags = {
    Name        = "${var.project_name}-bucket-improved"
    Improvement = "secure-configuration"
  }
}

# 改善: パブリックアクセスブロック有効
resource "aws_s3_bucket_public_access_block" "improved" {
  bucket = aws_s3_bucket.improved.id

  block_public_acls       = true  # 改善: パブリックACLブロック
  block_public_policy     = true  # 改善: パブリックポリシーブロック
  ignore_public_acls      = true  # 改善: パブリックACL無視
  restrict_public_buckets = true  # 改善: パブリックバケット制限
}

# 改善: バージョニング有効
resource "aws_s3_bucket_versioning" "improved" {
  bucket = aws_s3_bucket.improved.id

  versioning_configuration {
    status = "Enabled"
  }
}

# 改善: 暗号化設定
resource "aws_s3_bucket_server_side_encryption_configuration" "improved" {
  bucket = aws_s3_bucket.improved.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# 改善: ライフサイクルポリシー
resource "aws_s3_bucket_lifecycle_configuration" "improved" {
  bucket = aws_s3_bucket.improved.id

  rule {
    id     = "archive-old-versions"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

# ============================================
# 改善2: EBSボリューム暗号化有効
# ============================================
resource "aws_ebs_volume" "improved" {
  availability_zone = data.aws_availability_zones.available.names[0]
  size              = 20
  type              = "gp3"

  # 改善: 暗号化有効
  encrypted  = true
  kms_key_id = aws_kms_key.ebs.arn

  tags = {
    Name        = "${var.project_name}-ebs-improved"
    Improvement = "encryption-enabled-with-kms"
  }
}

resource "aws_volume_attachment" "improved" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.improved.id
  instance_id = aws_instance.improved.id
}

# KMSキー（EBS暗号化用）
resource "aws_kms_key" "ebs" {
  description             = "KMS key for EBS encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Name = "${var.project_name}-kms-ebs"
  }
}

resource "aws_kms_alias" "ebs" {
  name          = "alias/${var.project_name}-ebs"
  target_key_id = aws_kms_key.ebs.key_id
}

# ============================================
# 改善3: AWS Backup設定
# ============================================

# Backup Vault
resource "aws_backup_vault" "main" {
  name = "${var.project_name}-backup-vault"

  tags = {
    Name        = "${var.project_name}-backup-vault"
    Improvement = "automated-backups"
  }
}

# Backup Plan
resource "aws_backup_plan" "main" {
  name = "${var.project_name}-backup-plan"

  rule {
    rule_name         = "daily_backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 2 * * ? *)"  # 毎日2:00 UTC

    lifecycle {
      delete_after = 30
    }

    recovery_point_tags = {
      BackupType = "Daily"
    }
  }

  rule {
    rule_name         = "weekly_backup"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 3 ? * 1 *)"  # 毎週月曜3:00 UTC

    lifecycle {
      delete_after = 90
    }

    recovery_point_tags = {
      BackupType = "Weekly"
    }
  }

  tags = {
    Name = "${var.project_name}-backup-plan"
  }
}

# Backup Selection
resource "aws_backup_selection" "main" {
  name         = "${var.project_name}-backup-selection"
  plan_id      = aws_backup_plan.main.id
  iam_role_arn = aws_iam_role.backup.arn

  resources = [
    aws_instance.improved.arn,
    aws_ebs_volume.improved.arn
  ]
}

# Backup用IAMロール
resource "aws_iam_role" "backup" {
  name = "${var.project_name}-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-backup-role"
  }
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "backup_restore" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

# ============================================
# CloudWatch Logs
# ============================================
resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/${var.project_name}/application"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-log-group"
    Improvement = "centralized-logging"
  }
}

# ============================================
# Data Sources
# ============================================

data "aws_availability_zones" "available" {
  state = "available"
}

# 改善: 最新のAMIを使用
data "aws_ami" "latest_amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_caller_identity" "current" {}