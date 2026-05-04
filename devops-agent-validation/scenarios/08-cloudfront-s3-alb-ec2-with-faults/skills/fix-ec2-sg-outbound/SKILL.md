---
inclusion: manual
---

# Skill: EC2セキュリティグループ アウトバウンド修正

## 障害概要

EC2セキュリティグループのegressルールでHTTPS(443)のみ許可されており、HTTP(80)が未許可。外部APIへのHTTP通信やパッケージリポジトリへのアクセスが失敗する。

## 症状

- アプリケーションログに `connection timeout` や `ECONNREFUSED` エラー
- `dnf update` / `yum update` が失敗
- 外部Webhook通知が送信できない

## 根本原因

EC2セキュリティグループの egress で port 443 (HTTPS) のみ許可し、port 80 (HTTP) を許可していない。

## 復旧手順

### 1. 現状確認

```bash
# EC2セキュリティグループのegressルール確認
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=smb-webservice-ec2-sg" \
  --query 'SecurityGroups[0].IpPermissionsEgress'

# EC2からHTTP接続テスト（SSM経由）
aws ssm send-command \
  --instance-ids <INSTANCE_ID> \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["curl -v http://example.com --connect-timeout 5"]'
```

### 2. 修正（HTTP egressルール追加）

```bash
# HTTP(80)のegressを許可
aws ec2 authorize-security-group-egress \
  --group-id <EC2_SG_ID> \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0
```

### 3. Terraform修正

```hcl
# aws_security_group.ec2 の egress に追加
egress {
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  description = "HTTP outbound"
}
```

### 4. 復旧確認

```bash
# HTTP接続テスト
aws ssm send-command \
  --instance-ids <INSTANCE_ID> \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["curl -s -o /dev/null -w \"%{http_code}\" http://example.com"]'
```

## 予防策

- EC2のegressは用途に応じて必要なポートを明示的に許可
- 外部通信が必要な場合は HTTP(80) と HTTPS(443) の両方を許可
- NAT Gateway経由の通信でもセキュリティグループのegressルールは適用される
