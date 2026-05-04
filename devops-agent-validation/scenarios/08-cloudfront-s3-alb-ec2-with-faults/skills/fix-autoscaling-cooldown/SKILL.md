---
name: fix-autoscaling-cooldown
description: Auto Scalingのクールダウン期間が長すぎて負荷急増時にスケールアウトが遅延する問題を修正する。レスポンスタイム悪化やTargetResponseTimeアラーム発火時に使用。
---

# Skill: Auto Scaling クールダウン期間修正

## 障害概要

Auto Scaling Group のクールダウン期間が600秒（10分）に設定されており、負荷急増時にスケールアウトが大幅に遅延する。

## 症状

- 負荷急増時にレスポンスタイムが悪化（5秒以上）
- CloudWatch `TargetResponseTime` アラームが発火
- ASGのインスタンス数が増えるまで10分以上かかる
- ユーザーからの「サイトが重い」報告

## 根本原因

`aws_autoscaling_group.api` と `aws_autoscaling_policy.scale_out` の `cooldown` が 600秒に設定されている。スケールアウトアクション実行後、次のスケールアウトまで10分待機する必要がある。

## 復旧手順

### 1. 現状確認

```bash
# ASGの現在の設定確認
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names smb-webservice-api-asg \
  --query 'AutoScalingGroups[0].{DefaultCooldown:DefaultCooldown,MinSize:MinSize,MaxSize:MaxSize,DesiredCapacity:DesiredCapacity}'

# スケーリングポリシー確認
aws autoscaling describe-policies \
  --auto-scaling-group-name smb-webservice-api-asg
```

### 2. 緊急対応（手動スケールアウト）

```bash
# 即座にインスタンス数を増やす
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name smb-webservice-api-asg \
  --desired-capacity 4
```

### 3. クールダウン期間の修正

```bash
# ASGのデフォルトクールダウンを修正
aws autoscaling update-auto-scaling-group \
  --auto-scaling-group-name smb-webservice-api-asg \
  --default-cooldown 120

# スケールアウトポリシーのクールダウンを修正
aws autoscaling put-scaling-policy \
  --auto-scaling-group-name smb-webservice-api-asg \
  --policy-name smb-webservice-scale-out \
  --scaling-adjustment 1 \
  --adjustment-type ChangeInCapacity \
  --cooldown 120
```

### 4. Terraform修正

```hcl
# aws_autoscaling_group.api
resource "aws_autoscaling_group" "api" {
  # ...
  default_cooldown = 120  # 2分に短縮
  # ...
}

# aws_autoscaling_policy.scale_out
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "${var.project_name}-scale-out"
  scaling_adjustment     = 2           # 1台→2台に変更（急増対応）
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 120         # 2分に短縮
  autoscaling_group_name = aws_autoscaling_group.api.name
}
```

### 5. 推奨: Target Tracking Scaling への移行

```hcl
# より応答性の高いTarget Tracking Scalingを推奨
resource "aws_autoscaling_policy" "target_tracking" {
  name                   = "${var.project_name}-target-tracking"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.api.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.api.arn_suffix}/${aws_lb_target_group.api.arn_suffix}"
    }
    target_value = 100  # ターゲットあたり100リクエスト/分
  }
}
```

### 6. 復旧確認

```bash
# ASG設定確認
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names smb-webservice-api-asg \
  --query 'AutoScalingGroups[0].DefaultCooldown'
# 期待: 120

# レスポンスタイム確認
aws cloudwatch get-metric-statistics \
  --namespace "AWS/ApplicationELB" \
  --metric-name "TargetResponseTime" \
  --dimensions Name=LoadBalancer,Value=<ALB_ARN_SUFFIX> \
  --start-time $(date -u -d '10 minutes ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average
```

## 予防策

- クールダウン期間はアプリケーションの起動時間 + ウォームアップ時間を基準に設定
- Target Tracking Scaling を使用して自動的に最適なスケーリングを実現
- 予測スケーリング（Predictive Scaling）で定期的な負荷パターンに事前対応
- 負荷テストを定期的に実施してスケーリング設定の妥当性を検証
