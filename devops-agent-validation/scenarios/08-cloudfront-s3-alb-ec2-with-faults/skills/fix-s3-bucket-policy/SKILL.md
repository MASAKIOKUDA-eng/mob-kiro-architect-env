---
name: fix-s3-bucket-policy
description: S3バケットポリシーのDenyルールによりCloudFront OAC経由でもCSS/JSが403エラーになる問題を修正する。静的コンテンツが表示されない場合やCloudFront 4xxErrorRateが高い場合に使用。
---

# Skill: S3バケットポリシー修正（CloudFront OACアクセス許可）

## 障害概要

S3バケットポリシーに `/assets/*` パスへのアクセスを拒否するDenyルールが含まれており、CloudFront OAC経由でもCSS/JSファイルが403エラーになる。

## 症状

- Webサイトの `index.html` は表示されるが、スタイルが適用されない
- ブラウザのDevToolsで `/assets/style.css` と `/assets/app.js` が 403
- CloudWatch `4xxErrorRate` アラームが発火

## 根本原因

S3バケットポリシーの `DenyAssets` ステートメントが、CloudFrontサービスプリンシパルからのアクセスも拒否している。Deny は Allow より優先されるため、OACの許可ルールがあっても拒否される。

## 復旧手順

### 1. 現状確認

```bash
# バケットポリシー確認
aws s3api get-bucket-policy \
  --bucket <BUCKET_NAME> \
  --query 'Policy' | jq .

# CloudFront経由でアクセステスト
curl -I https://<CLOUDFRONT_DOMAIN>/assets/style.css
```

### 2. 修正（Denyルール削除）

```bash
# 修正したバケットポリシーを適用
aws s3api put-bucket-policy \
  --bucket <BUCKET_NAME> \
  --policy '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "AllowCloudFrontOAC",
        "Effect": "Allow",
        "Principal": { "Service": "cloudfront.amazonaws.com" },
        "Action": "s3:GetObject",
        "Resource": "arn:aws:s3:::<BUCKET_NAME>/*",
        "Condition": {
          "StringEquals": {
            "AWS:SourceArn": "arn:aws:cloudfront::<ACCOUNT_ID>:distribution/<DISTRIBUTION_ID>"
          }
        }
      }
    ]
  }'
```

### 3. Terraform修正

```hcl
# aws_s3_bucket_policy.static から DenyAssets ステートメントを削除
resource "aws_s3_bucket_policy" "static" {
  bucket = aws_s3_bucket.static.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontOAC"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "$${aws_s3_bucket.static.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.main.arn
          }
        }
      }
    ]
  })
}
```

### 4. 復旧確認

```bash
# アセットファイルへのアクセス確認
curl -s -o /dev/null -w "%{http_code}" https://<CLOUDFRONT_DOMAIN>/assets/style.css
# 期待: 200

curl -s -o /dev/null -w "%{http_code}" https://<CLOUDFRONT_DOMAIN>/assets/app.js
# 期待: 200
```

## 予防策

- S3バケットポリシーでDenyルールを使う場合は、影響範囲を慎重に検討
- CloudFront OACを使用する場合、Denyルールの Condition で CloudFront を除外する
- デプロイ後に全アセットの疎通確認を自動テストに含める
