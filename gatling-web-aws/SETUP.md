# セットアップガイド

## 前提条件

### 1. Terraformのインストール

```bash
# Windows (Chocolatey)
choco install terraform

# macOS (Homebrew)
brew install terraform

# Linux
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

### 2. AWS CLIの設定

```bash
aws configure
```

以下の情報を入力：
- AWS Access Key ID
- AWS Secret Access Key
- Default region name: `ap-northeast-1`
- Default output format: `json`

## デプロイ手順

### 1. EC2単体構成

```bash
cd 01-ec2-single
terraform init
terraform plan
terraform apply

# 出力されたURLにアクセス
# 例: http://54.123.45.67
```

**デプロイ時間**: 約3-5分

### 2. EC2 + ALB構成

```bash
cd 02-ec2-alb
terraform init
terraform plan
terraform apply

# 出力されたALB URLにアクセス
# 例: http://gatling-alb-123456789.ap-northeast-1.elb.amazonaws.com
```

**デプロイ時間**: 約5-7分

**注意**: ALBのヘルスチェックが完了するまで数分かかります。

### 3. S3 + CloudFront構成

```bash
cd 03-s3-cloudfront
terraform init
terraform plan
terraform apply

# 出力されたCloudFront URLにアクセス
# 例: https://d123456789abcd.cloudfront.net
```

**デプロイ時間**: 約15-20分（CloudFrontの配布に時間がかかります）

## 動作確認

各構成のデプロイ後、ブラウザで出力されたURLにアクセスしてください。

### 確認ポイント

1. **ページが正常に表示される**
2. **Server Type が正しく表示される**
   - EC2単体: "EC2 Single Instance"
   - EC2 + ALB: "EC2 + ALB"
   - S3 + CloudFront: "S3 + CloudFront"
3. **リロードするとRequest Countが増加する**

### ALB構成の負荷分散確認

```bash
# 複数回アクセスして、異なるEC2インスタンスに振り分けられることを確認
for i in {1..10}; do
  curl http://your-alb-url.elb.amazonaws.com | grep "Server Name"
done
```

## リソースの削除

**重要**: 使用後は必ずリソースを削除してください（課金を避けるため）

```bash
# 各ディレクトリで実行
terraform destroy

# 確認プロンプトで "yes" を入力
```

### 削除順序（推奨）

1. S3 + CloudFront（最も時間がかかる）
2. EC2 + ALB
3. EC2単体

## トラブルシューティング

### EC2インスタンスにアクセスできない

```bash
# セキュリティグループを確認
aws ec2 describe-security-groups --group-ids <security-group-id>

# インスタンスの状態を確認
aws ec2 describe-instances --instance-ids <instance-id>
```

### ALBのヘルスチェックが失敗する

```bash
# ターゲットグループの状態を確認
aws elbv2 describe-target-health --target-group-arn <target-group-arn>

# EC2インスタンスのログを確認
aws ec2 get-console-output --instance-id <instance-id>
```

### CloudFrontが403エラーを返す

- S3バケットポリシーが正しく設定されているか確認
- CloudFrontの配布が完了しているか確認（15-20分かかる場合があります）

```bash
# CloudFrontディストリビューションの状態を確認
aws cloudfront get-distribution --id <distribution-id>
```

## コスト見積もり

### 月額概算（東京リージョン）

1. **EC2単体**: 約$10-15
   - t3.micro × 1台
   - データ転送

2. **EC2 + ALB**: 約$30-40
   - t3.micro × 2台
   - ALB
   - データ転送

3. **S3 + CloudFront**: 約$5-10
   - S3ストレージ（最小）
   - CloudFront配信
   - データ転送

**注意**: 実際のコストは使用量によって変動します。

## セキュリティに関する注意

このプロジェクトはデモ用です。本番環境では以下を考慮してください：

1. **HTTPSの使用**: ACMで証明書を取得してHTTPSを有効化
2. **セキュリティグループの制限**: 必要最小限のアクセスのみ許可
3. **IAMロールの使用**: アクセスキーの代わりにIAMロールを使用
4. **ログの有効化**: CloudWatch Logs、ALBアクセスログなど
5. **WAFの導入**: CloudFront + WAFで保護

## 参考リンク

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)
- [AWS ALB Documentation](https://docs.aws.amazon.com/elasticloadbalancing/)
- [AWS CloudFront Documentation](https://docs.aws.amazon.com/cloudfront/)