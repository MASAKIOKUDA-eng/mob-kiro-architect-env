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
      Environment = "ECR-Lambda-Problematic"
      ManagedBy   = "Terraform"
      Scenario    = "05"
    }
  }
}

# ============================================
# ECR観点の問題
# ============================================

# 問題1: イメージスキャン無効
resource "aws_ecr_repository" "problematic" {
  name = "${var.project_name}-problematic-repo"

  # 問題: イメージスキャン無効
  image_scanning_configuration {
    scan_on_push = false
  }

  # 問題: タグのイミュータビリティ無効
  image_tag_mutability = "MUTABLE"

  # 問題: ライフサイクルポリシーなし（古いイメージが残り続ける）
  
  tags = {
    Name   = "${var.project_name}-ecr-problematic"
    Issues = "no-image-scanning,mutable-tags,no-lifecycle-policy,no-encryption"
  }
}

# 問題2: ECRリポジトリポリシーが過度に開放
resource "aws_ecr_repository_policy" "problematic" {
  repository = aws_ecr_repository.problematic.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPullFromAnyAccount"
        Effect = "Allow"
        Principal = {
          AWS = "*"  # 問題: すべてのAWSアカウントに開放
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

# ============================================
# Lambda観点の問題
# ============================================

# 問題1: Lambda関数のIAMロールが過度に権限付与
resource "aws_iam_role" "lambda_problematic" {
  name = "${var.project_name}-lambda-problematic-role"

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
    Name  = "${var.project_name}-lambda-role-problematic"
    Issue = "overly-permissive-iam-role"
  }
}

# 問題: 管理者権限を付与
resource "aws_iam_role_policy_attachment" "lambda_admin" {
  role       = aws_iam_role.lambda_problematic.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# 問題2: 環境変数に機密情報をプレーンテキストで保存
resource "aws_lambda_function" "problematic" {
  function_name = "${var.project_name}-function-problematic"
  role          = aws_iam_role.lambda_problematic.arn
  
  # 問題: パブリックECRイメージを使用（セキュリティリスク）
  package_type = "Image"
  image_uri    = "public.ecr.aws/lambda/python:3.11"

  # 問題: 環境変数に機密情報をプレーンテキストで保存
  environment {
    variables = {
      DB_PASSWORD      = "MySecretPassword123!"  # 問題: プレーンテキスト
      API_KEY          = "sk-1234567890abcdef"   # 問題: プレーンテキスト
      AWS_ACCESS_KEY   = "AKIAIOSFODNN7EXAMPLE"  # 問題: ハードコード
      AWS_SECRET_KEY   = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
      LOG_LEVEL        = "DEBUG"
    }
  }

  # 問題: タイムアウトが長すぎる
  timeout = 900  # 15分

  # 問題: メモリが過剰
  memory_size = 10240  # 10GB

  # 問題: 予約済み同時実行数の設定なし（コスト制御なし）
  
  # 問題: トレーシング無効
  tracing_config {
    mode = "PassThrough"
  }

  # 問題: デッドレターキュー未設定
  
  tags = {
    Name   = "${var.project_name}-lambda-problematic"
    Issues = "plaintext-secrets,excessive-permissions,no-dlq,no-tracing,public-image"
  }
}

# 問題3: Lambda関数URLがパブリックアクセス可能
resource "aws_lambda_function_url" "problematic" {
  function_name      = aws_lambda_function.problematic.function_name
  authorization_type = "NONE"  # 問題: 認証なし

  cors {
    allow_origins = ["*"]  # 問題: すべてのオリジンを許可
    allow_methods = ["*"]
    allow_headers = ["*"]
  }
}

# 問題4: CloudWatch Logsの保持期間が無期限
resource "aws_cloudwatch_log_group" "lambda_problematic" {
  name = "/aws/lambda/${aws_lambda_function.problematic.function_name}"
  
  # 問題: 保持期間未設定（無期限、コスト増加）
  # retention_in_days = null

  tags = {
    Name  = "${var.project_name}-lambda-logs-problematic"
    Issue = "unlimited-log-retention"
  }
}

# ============================================
# 問題5: VPC設定なし（ネットワーク分離なし）
# ============================================
# Lambda関数がVPC外で実行され、プライベートリソースへのアクセスが
# インターネット経由になる

# ============================================
# 問題6: バージョニングとエイリアスの欠如
# ============================================
# Lambda関数のバージョン管理なし
# Blue/Greenデプロイメント不可
# ロールバック困難

# ============================================
# Data Sources
# ============================================

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}
