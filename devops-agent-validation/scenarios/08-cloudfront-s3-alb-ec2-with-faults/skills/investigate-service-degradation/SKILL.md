---
inclusion: manual
---

# Skill: サービス劣化の総合調査手順

## 概要

中小企業Webサービス（CloudFront + S3 + ALB + EC2構成）でサービス劣化が報告された場合の体系的な調査手順。

## 調査フロー

```
1. アラーム状態確認
   ↓
2. CloudFront → S3 経路の確認
   ↓
3. CloudFront → ALB → EC2 経路の確認
   ↓
4. EC2インスタンスの状態確認
   ↓
5. ログ分析
   ↓
6. 根本原因の特定と復旧
```

## Step 1: アラーム状態の一括確認

```bash
# 全アラームの状態確認
aws cloudwatch describe-alarms \
  --alarm-name-prefix "smb-webservice" \
  --query 'MetricAlarms[?StateValue!=`OK`].{Name:AlarmName,State:StateValue,Reason:StateReason}'
```

## Step 2: CloudFront → S3 経路

```bash
# CloudFront エラー率確認
aws cloudwatch get-metric-statistics \
  --namespace "AWS/CloudFront" \
  --metric-name "4xxErrorRate" \
  --dimensions Name=DistributionId,Value=<DIST_ID> Name=Region,Value=Global \
  --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 --statistics Average

# S3バケットポリシー確認
aws s3api get-bucket-policy --bucket <BUCKET_NAME>

# OAC設定確認
aws cloudfront get-distribution --id <DIST_ID> \
  --query 'Distribution.DistributionConfig.Origins.Items[?Id==`S3-*`]'
```

## Step 3: CloudFront → ALB → EC2 経路

```bash
# ALB ターゲットヘルス確認
aws elbv2 describe-target-health \
  --target-group-arn <TG_ARN>

# ALB 5xx エラー確認
aws cloudwatch get-metric-statistics \
  --namespace "AWS/ApplicationELB" \
  --metric-name "HTTPCode_ELB_5XX_Count" \
  --dimensions Name=LoadBalancer,Value=<ALB_ARN_SUFFIX> \
  --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 --statistics Sum

# セキュリティグループ確認
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=smb-webservice-*" \
  --query 'SecurityGroups[].{Name:GroupName,Ingress:IpPermissions,Egress:IpPermissionsEgress}'
```

## Step 4: EC2インスタンスの状態確認

```bash
# インスタンスステータス
aws ec2 describe-instance-status \
  --filters "Name=tag:Name,Values=smb-webservice-api-server"

# SSM経由でシステム状態確認
aws ssm send-command \
  --targets "Key=tag:Name,Values=smb-webservice-api-server" \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "df -h",
    "free -m",
    "systemctl status api-server",
    "curl -s http://localhost:3000/api/health",
    "/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a status"
  ]'
```

## Step 5: ログ分析

```bash
# VPC Flow Logs で REJECT 確認
aws logs filter-log-events \
  --log-group-name "/aws/smb-webservice/vpc-flow-logs" \
  --filter-pattern "REJECT" \
  --start-time $(date -d '30 minutes ago' +%s000) \
  --limit 20

# アプリケーションエラーログ確認
aws logs filter-log-events \
  --log-group-name "/aws/smb-webservice/error" \
  --start-time $(date -d '30 minutes ago' +%s000) \
  --limit 20

# ログが届いていない場合はCloudWatch Agent設定を確認
aws logs describe-log-streams \
  --log-group-name "/aws/smb-webservice/application" \
  --order-by LastEventTime \
  --descending \
  --limit 3
```

## Step 6: Auto Scaling 状態確認

```bash
# ASGアクティビティ確認
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name smb-webservice-api-asg \
  --max-items 10

# スケーリングポリシー確認
aws autoscaling describe-policies \
  --auto-scaling-group-name smb-webservice-api-asg
```

## 判断マトリクス

| 症状 | 確認ポイント | 該当Skill |
|------|-------------|-----------|
| 全ターゲット unhealthy | ヘルスチェックパス | fix-healthcheck-path |
| VPC Flow Logs に REJECT 多数 | SG egress ルール | fix-alb-sg-ephemeral-ports |
| 外部API接続失敗 | EC2 SG egress | fix-ec2-sg-outbound |
| ディスク使用率 90%+ | /var/log サイズ | fix-disk-space |
| 静的コンテンツ 403 | S3バケットポリシー | fix-s3-bucket-policy |
| デプロイ反映されない | CloudFront TTL | fix-cloudfront-cache-ttl |
| ログ未受信 | CW Agent 設定 | fix-cloudwatch-agent-config |
| レスポンス遅延 | ASG クールダウン | fix-autoscaling-cooldown |
