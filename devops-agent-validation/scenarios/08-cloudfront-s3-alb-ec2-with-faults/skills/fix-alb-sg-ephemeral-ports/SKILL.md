---
name: fix-alb-sg-ephemeral-ports
description: ALBセキュリティグループのegressにエフェメラルポートが未許可でヘルスチェックが失敗する問題を修正する。ALBターゲットがunhealthyになった場合やVPC Flow LogsにREJECTが多数ある場合に使用。
---

# Skill: ALBセキュリティグループ エフェメラルポート修正

## 障害概要

ALBのセキュリティグループのegressルールにエフェメラルポート（1024-65535）が許可されていないため、ALBからEC2へのヘルスチェック応答が正常に返せない。

## 症状

- ALBターゲットグループのターゲットが全て `unhealthy`
- CloudWatch `UnHealthyHostCount` アラームが発火
- VPC Flow Logs に REJECT エントリが多数

## 根本原因

ALBセキュリティグループの egress ルールで port 80 のみ許可しており、EC2からの応答（エフェメラルポート 1024-65535）が通過できない。

## 復旧手順

### 1. 現状確認

```bash
# ALBセキュリティグループのルール確認
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=smb-webservice-alb-sg" \
  --query 'SecurityGroups[0].IpPermissionsEgress'

# ターゲットヘルス確認
aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN>
```

### 2. 修正（egressルール追加）

```bash
# エフェメラルポートのegressを許可
aws ec2 authorize-security-group-egress \
  --group-id <ALB_SG_ID> \
  --protocol tcp \
  --port 1024-65535 \
  --cidr 10.0.0.0/16
```

### 3. Terraform修正

```hcl
# aws_security_group.alb の egress に追加
egress {
  from_port   = 1024
  to_port     = 65535
  protocol    = "tcp"
  cidr_blocks = ["10.0.0.0/16"]
  description = "Ephemeral ports for health check responses"
}
```

### 4. 復旧確認

```bash
# ターゲットが healthy になるまで待機（最大30秒）
aws elbv2 wait target-in-service \
  --target-group-arn <TARGET_GROUP_ARN>

# ヘルス確認
aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN>
```

## 予防策

- セキュリティグループ設計時にステートフルな通信の応答ポートを考慮する
- ALBのegressは最低限 VPC CIDR への全ポート許可を推奨
