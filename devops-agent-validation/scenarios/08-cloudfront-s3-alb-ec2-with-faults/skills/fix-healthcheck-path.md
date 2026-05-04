---
inclusion: manual
---

# Skill: ALBヘルスチェックパス不一致の修正

## 障害概要

ALBターゲットグループのヘルスチェックパスが `/health` に設定されているが、アプリケーションは `/api/health` でヘルスチェックに応答する。全ターゲットが unhealthy と判定され、503エラーが返される。

## 症状

- ALB経由のリクエストが全て 503 Service Unavailable
- CloudWatch `UnHealthyHostCount` が常に 2（全インスタンス）
- EC2インスタンス自体は正常稼働中（SSM経由で確認可能）

## 根本原因

ALBターゲットグループの `health_check.path` が `/health` だが、Node.jsアプリケーションのヘルスチェックエンドポイントは `/api/health` に実装されている。

## 復旧手順

### 1. 現状確認

```bash
# ターゲットグループのヘルスチェック設定確認
aws elbv2 describe-target-groups \
  --names smb-webservice-api-tg \
  --query 'TargetGroups[0].HealthCheckPath'

# ターゲットヘルス確認
aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN>

# EC2上でアプリの応答確認
aws ssm send-command \
  --instance-ids <INSTANCE_ID> \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "curl -s http://localhost:3000/health || echo NOT_FOUND",
    "curl -s http://localhost:3000/api/health"
  ]'
```

### 2. 修正（ヘルスチェックパス変更）

```bash
# ターゲットグループのヘルスチェックパスを修正
aws elbv2 modify-target-group \
  --target-group-arn <TARGET_GROUP_ARN> \
  --health-check-path "/api/health"
```

### 3. Terraform修正

```hcl
# aws_lb_target_group.api の health_check を修正
health_check {
  enabled             = true
  healthy_threshold   = 2
  interval            = 30
  matcher             = "200"
  path                = "/api/health"  # 修正: アプリの実際のパスに合わせる
  port                = "traffic-port"
  protocol            = "HTTP"
  timeout             = 5
  unhealthy_threshold = 3
}
```

### 4. 復旧確認

```bash
# ターゲットが healthy になるまで待機
aws elbv2 wait target-in-service \
  --target-group-arn <TARGET_GROUP_ARN>

# ALB経由でAPIアクセス確認
curl -s http://<ALB_DNS_NAME>/api/status
```

## 予防策

- ヘルスチェックパスはアプリケーション開発チームと合意の上で設定
- IaC（Terraform）とアプリケーションコードで同じ定数/変数を参照する仕組みを導入
- デプロイパイプラインでヘルスチェックの疎通確認を自動テストに含める
