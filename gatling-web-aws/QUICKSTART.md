# クイックスタートガイド

## 最速でデプロイする

### 1. AWS認証情報の設定

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="ap-northeast-1"
```

### 2. EC2単体構成をデプロイ（最も簡単）

```bash
cd 01-ec2-single
terraform init
terraform apply -auto-approve
```

約3分後、URLが出力されます：

```
Outputs:

web_server_url = "http://54.123.45.67"
```

ブラウザでアクセスして確認！

### 3. リソースの削除

```bash
terraform destroy -auto-approve
```

## 全構成を一度にデプロイ

```bash
# EC2単体
cd 01-ec2-single && terraform init && terraform apply -auto-approve && cd ..

# EC2 + ALB
cd 02-ec2-alb && terraform init && terraform apply -auto-approve && cd ..

# S3 + CloudFront
cd 03-s3-cloudfront && terraform init && terraform apply -auto-approve && cd ..
```

## 全構成を一度に削除

```bash
cd 03-s3-cloudfront && terraform destroy -auto-approve && cd ..
cd 02-ec2-alb && terraform destroy -auto-approve && cd ..
cd 01-ec2-single && terraform destroy -auto-approve && cd ..
```

## よくある質問

### Q: どの構成から始めるべき？

A: **01-ec2-single**から始めてください。最もシンプルで、デプロイも速いです。

### Q: 料金はいくらかかる？

A: 
- EC2単体: 1時間あたり約$0.01-0.02
- EC2 + ALB: 1時間あたり約$0.03-0.05
- S3 + CloudFront: 1時間あたり約$0.01-0.02

**重要**: 使用後は必ず`terraform destroy`でリソースを削除してください！

### Q: デプロイに失敗した

A: 以下を確認してください：
1. AWS認証情報が正しいか
2. リージョンにEC2の起動制限がないか
3. `terraform init`を実行したか

### Q: Webページが表示されない

A: 
1. EC2インスタンスの起動完了まで2-3分待つ
2. セキュリティグループでポート80が開いているか確認
3. `terraform output`でURLを再確認

## トラブルシューティング

### エラー: "Error launching source instance"

```bash
# 別のインスタンスタイプを試す
terraform apply -var="instance_type=t2.micro"
```

### エラー: "InvalidGroup.NotFound"

```bash
# リソースをクリーンアップして再デプロイ
terraform destroy
terraform apply
```

### CloudFrontが403エラー

CloudFrontの配布完了まで15-20分待ってください。

```bash
# ステータス確認
terraform output cloudfront_domain_name
```