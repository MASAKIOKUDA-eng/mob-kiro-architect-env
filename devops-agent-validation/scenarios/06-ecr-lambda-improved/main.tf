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
      Environment = "ECR-Lambda-Improved"
      ManagedBy   = "Terraform"
      Scenario    = "06"
    }
  }
}

# ============================================
# VPC for Lambda (Network Isolation)
# ============================================

resource "aws_vpc" "main" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc-lambda"
  }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.1.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-subnet-private-${count.index + 1}"
  }
}

resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-sg-lambda"
  description = "Security group for Lambda functions"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS outbound"
  }

  tags = {
    Name = "${var.project_name}-sg-lambda"
  }
}

# ============================================
# ECR - Improved Configuration
# ============================================

# 改善1: イメージスキャン有効化
resource "aws_ecr_repository" "improved" {
  name = "${var.project_name}-improved-repo"

  # 改善: イメージスキャン有効
  image_scanning_configuration {
    scan_on_push = true
  }

  # 改善: タグのイミュータビリティ有効
  image_tag_mutability = "IMMUTABLE"

  # 改善: 暗号化設定
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.ecr.arn
  }

  tags = {
    Name         = "${var.project_name}-ecr-improved"
    Improvements = "image-scanning,immutable-tags,kms-encryption,lifecycle-policy"
  }
}

# 改善2: ライフサイクルポリシー設定
resource "aws_ecr_lifecycle_policy" "improved" {
  repository = aws_ecr_repository.improved.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Remove untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# 改善3: ECRリポジトリポリシーを最小権限に
resource "aws_ecr_repository_policy" "improved" {
  repository = aws_ecr_repository.improved.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPullFromSpecificRole"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.lambda_improved.arn
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}

# KMS key for ECR encryption
resource "aws_kms_key" "ecr" {
  description             = "KMS key for ECR encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Name = "${var.project_name}-ecr-kms"
  }
}

resource "aws_kms_alias" "ecr" {
  name          = "alias/${var.project_name}-ecr"
  target_key_id = aws_kms_key.ecr.key_id
}

# ============================================
# Secrets Manager for Lambda Environment Variables
# ============================================

resource "aws_secretsmanager_secret" "lambda_secrets" {
  name                    = "${var.project_name}-lambda-secrets"
  description             = "Secrets for Lambda function"
  recovery_window_in_days = 7

  tags = {
    Name = "${var.project_name}-lambda-secrets"
  }
}

resource "aws_secretsmanager_secret_version" "lambda_secrets" {
  secret_id = aws_secretsmanager_secret.lambda_secrets.id
  secret_string = jsonencode({
    db_password = "SecurePassword123!"
    api_key     = "sk-secure-key-example"
  })
}

# ============================================
# Lambda - Improved Configuration
# ============================================

# 改善1: Lambda関数のIAMロールを最小権限に
resource "aws_iam_role" "lambda_improved" {
  name = "${var.project_name}-lambda-improved-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-lambda-role-improved"
    Improvement = "least-privilege-iam"
  }
}

# 改善: 必要最小限の権限のみ付与
resource "aws_iam_role_policy" "lambda_improved" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_improved.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project_name}-function-improved:*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.lambda_secrets.arn
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      }
    ]
  })
}

# 改善: SQS Dead Letter Queue
resource "aws_sqs_queue" "lambda_dlq" {
  name                      = "${var.project_name}-lambda-dlq"
  message_retention_seconds = 1209600  # 14 days

  tags = {
    Name = "${var.project_name}-lambda-dlq"
  }
}

# 改善2: Lambda関数の設定を最適化
resource "aws_lambda_function" "improved" {
  function_name = "${var.project_name}-function-improved"
  role          = aws_iam_role.lambda_improved.arn
  
  # 改善: プライベートECRイメージを使用
  package_type = "Image"
  image_uri    = "${aws_ecr_repository.improved.repository_url}:latest"

  # 改善: 環境変数に機密情報を含めない
  environment {
    variables = {
      SECRETS_ARN = aws_secretsmanager_secret.lambda_secrets.arn
      LOG_LEVEL   = "INFO"
      ENVIRONMENT = "production"
    }
  }

  # 改善: 適切なタイムアウト設定
  timeout = 30  # 30秒

  # 改善: 適切なメモリ設定
  memory_size = 512  # 512MB

  # 改善: 予約済み同時実行数でコスト制御
  reserved_concurrent_executions = 10

  # 改善: X-Rayトレーシング有効
  tracing_config {
    mode = "Active"
  }

  # 改善: デッドレターキュー設定
  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  # 改善: VPC設定でネットワーク分離
  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  tags = {
    Name         = "${var.project_name}-lambda-improved"
    Improvements = "secrets-manager,least-privilege,dlq,tracing,vpc,versioning"
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_improved
  ]
}

# 改善3: Lambda関数のバージョニング
resource "aws_lambda_alias" "improved_prod" {
  name             = "production"
  description      = "Production alias for Lambda function"
  function_name    = aws_lambda_function.improved.function_name
  function_version = aws_lambda_function.improved.version
}

# 改善4: CloudWatch Logsの保持期間設定
resource "aws_cloudwatch_log_group" "lambda_improved" {
  name              = "/aws/lambda/${var.project_name}-function-improved"
  retention_in_days = 30  # 改善: 30日間保持

  tags = {
    Name        = "${var.project_name}-lambda-logs-improved"
    Improvement = "log-retention-policy"
  }
}

# 改善5: Lambda関数URLに認証を追加
resource "aws_lambda_function_url" "improved" {
  function_name      = aws_lambda_function.improved.function_name
  authorization_type = "AWS_IAM"  # 改善: IAM認証必須

  cors {
    allow_origins = ["https://example.com"]  # 改善: 特定のオリジンのみ
    allow_methods = ["GET", "POST"]
    allow_headers = ["content-type"]
    max_age       = 86400
  }
}

# ============================================
# CloudWatch Alarms for Monitoring
# ============================================

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project_name}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "This metric monitors Lambda function errors"

  dimensions = {
    FunctionName = aws_lambda_function.improved.function_name
  }

  tags = {
    Name = "${var.project_name}-lambda-errors-alarm"
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${var.project_name}-lambda-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Average"
  threshold           = 25000  # 25 seconds
  alarm_description   = "This metric monitors Lambda function duration"

  dimensions = {
    FunctionName = aws_lambda_function.improved.function_name
  }

  tags = {
    Name = "${var.project_name}-lambda-duration-alarm"
  }
}

# ============================================
# Data Sources
# ============================================

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}
