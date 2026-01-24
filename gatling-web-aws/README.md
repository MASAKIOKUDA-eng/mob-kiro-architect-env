# Gatling Web AWS

TerraformでAWS上に3種類のWebサーバー構成を構築するプロジェクト

## 構成

1. **EC2単体** - シンプルなEC2インスタンスでWebサーバーを構築
2. **EC2 + ALB** - 2台のEC2インスタンスとALBを組み合わせた構成
3. **S3 + CloudFront** - 静的サイトホスティング構成

## 前提条件

- Terraform 1.0以上
- AWS CLI設定済み
- 適切なAWS認証情報

## 使用方法

### 1. EC2単体構成

```bash
cd 01-ec2-single
terraform init
terraform plan
terraform apply
```

### 2. EC2 + ALB構成

```bash
cd 02-ec2-alb
terraform init
terraform plan
terraform apply
```

### 3. S3 + CloudFront構成

```bash
cd 03-s3-cloudfront
terraform init
terraform plan
terraform apply
```

## クリーンアップ

```bash
terraform destroy
```