---
inclusion: manual
---

# Skill: ディスク容量不足の復旧

## 障害概要

cronジョブにより `/var/log/dummy-data.log` が肥大化し、ディスク容量が枯渇。アプリケーションのログ書き込みが失敗し、最終的にサービスがクラッシュする。

## 症状

- アプリケーションが応答しない（503エラー）
- CloudWatch カスタムメトリクス `DiskSpaceUtilization` が 90% 超
- SSM経由で `df -h` を実行すると `/` が 95%+ 使用

## 根本原因

`/etc/cron.d/disk-filler` に登録されたcronジョブが1分ごとに50MBのダミーデータを `/var/log/dummy-data.log` に追記している。

## 復旧手順

### 1. 現状確認

```bash
# ディスク使用量確認
aws ssm send-command \
  --instance-ids <INSTANCE_ID> \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["df -h", "du -sh /var/log/*  | sort -rh | head -10"]'
```

### 2. 緊急対応（ダミーファイル削除 + cron停止）

```bash
aws ssm send-command \
  --instance-ids <INSTANCE_ID> \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "rm -f /etc/cron.d/disk-filler",
    "rm -f /var/log/dummy-data.log",
    "systemctl restart crond",
    "df -h"
  ]'
```

### 3. アプリケーション復旧

```bash
aws ssm send-command \
  --instance-ids <INSTANCE_ID> \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "systemctl restart api-server",
    "sleep 3",
    "curl -s http://localhost:3000/api/health"
  ]'
```

### 4. 復旧確認

```bash
# ディスク使用量が正常に戻ったことを確認
aws ssm send-command \
  --instance-ids <INSTANCE_ID> \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["df -h /"]'

# アプリケーションが正常応答することを確認
aws ssm send-command \
  --instance-ids <INSTANCE_ID> \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["curl -s http://localhost:3000/api/health"]'
```

## 予防策

- CloudWatch Agent でディスク使用率を監視し、80%でアラート
- logrotate を設定してログファイルのローテーションを自動化
- EBSボリュームの自動拡張（AWS Systems Manager Automation）を検討
- 不審なcronジョブの定期監査
