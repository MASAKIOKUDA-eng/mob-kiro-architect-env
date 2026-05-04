---
inclusion: manual
---

# Skill: CloudWatch Agent 設定ミス修正

## 障害概要

CloudWatch Agentの設定ファイルで指定されているログファイルパスが実際のアプリケーションログパスと異なるため、ログが CloudWatch Logs に送信されない。

## 症状

- CloudWatch Logs のロググループにログイベントが届かない
- CloudWatch アラーム `IncomingLogEvents < 1` が発火
- EC2インスタンス上にはログファイルが存在する（SSM経由で確認可能）

## 根本原因

CloudWatch Agent 設定ファイル (`/opt/aws/amazon-cloudwatch-agent/etc/config.json`) で以下のパスが指定されている:
- 設定: `/var/log/app/access.log`, `/var/log/app/error.log`
- 実際: `/var/log/api/access.log`, `/var/log/api/error.log`

`/var/log/app/` ディレクトリは存在しないため、ログ収集が行われない。

## 復旧手順

### 1. 現状確認

```bash
# CloudWatch Agent のステータス確認
aws ssm send-command \
  --instance-ids <INSTANCE_ID> \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a status",
    "cat /opt/aws/amazon-cloudwatch-agent/etc/config.json | grep file_path",
    "ls -la /var/log/api/",
    "ls -la /var/log/app/ 2>&1 || echo DIRECTORY_NOT_FOUND"
  ]'
```

### 2. 設定ファイル修正

```bash
aws ssm send-command \
  --instance-ids <INSTANCE_ID> \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "sed -i \"s|/var/log/app/access.log|/var/log/api/access.log|g\" /opt/aws/amazon-cloudwatch-agent/etc/config.json",
    "sed -i \"s|/var/log/app/error.log|/var/log/api/error.log|g\" /opt/aws/amazon-cloudwatch-agent/etc/config.json",
    "cat /opt/aws/amazon-cloudwatch-agent/etc/config.json | grep file_path"
  ]'
```

### 3. CloudWatch Agent 再起動

```bash
aws ssm send-command \
  --instance-ids <INSTANCE_ID> \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json",
    "sleep 5",
    "/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a status"
  ]'
```

### 4. Terraform修正（user-data.sh）

```bash
# user-data.sh 内の CloudWatch Agent 設定を修正
# 変更前:
#   "file_path": "/var/log/app/access.log"
#   "file_path": "/var/log/app/error.log"
# 変更後:
#   "file_path": "/var/log/api/access.log"
#   "file_path": "/var/log/api/error.log"
```

### 5. 復旧確認

```bash
# CloudWatch Logs にログが届いているか確認（1-2分待機後）
aws logs filter-log-events \
  --log-group-name "/aws/smb-webservice/application" \
  --start-time $(date -d '5 minutes ago' +%s000) \
  --limit 5

# IncomingLogEvents メトリクスが 0 より大きいことを確認
aws cloudwatch get-metric-statistics \
  --namespace "AWS/Logs" \
  --metric-name "IncomingLogEvents" \
  --dimensions Name=LogGroupName,Value="/aws/smb-webservice/application" \
  --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

## 予防策

- CloudWatch Agent 設定をデプロイ後に自動テスト（ログ到達確認）
- アプリケーションのログパスを環境変数で統一管理
- SSM Parameter Store に CloudWatch Agent 設定を保存し、一元管理
- CloudWatch Logs の `IncomingLogEvents` メトリクスでゼロ検知アラームを設定
