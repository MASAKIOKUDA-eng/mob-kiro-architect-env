# CloudFront + NLB + ALB + EC2 構成（5つの設定ミスを含むシナリオ）

このシナリオは、CloudFront、Network Load Balancer (NLB)、Application Load Balancer (ALB)、EC2インスタンス（3台）を含む構成で、**意図的に5つのネットワーク設定ミスを含んでいます**。

## 構成概要

```
Internet → CloudFront → ALB → EC2 (3台)
                     ↗ NLB ↗
```

## 含まれている5つの設定ミス

### 【設定ミス1】パブリックサブネットの可用性ゾーン配置
- **問題**: パブリックサブネット2つが同じAZ（ap-northeast-1a）に配置されている
- **影響**: 単一AZ障害時にALBが利用不可になる
- **場所**: `aws_subnet.public_1` と `aws_subnet.public_2`

### 【設定ミス2】ALBセキュリティグループの過度な開放
- **問題**: ALBのセキュリティグループでSSHポート（22）を全てのIPから許可
- **影響**: 不要なポートが開放され、セキュリティリスクが増大
- **場所**: `aws_security_group.alb` の ingress ルール

### 【設定ミス3】NLBの不適切な配置設定
- **問題**: 内部用途のNLBがインターネット向け（internal = false）に設定されている
- **影響**: 意図しない外部アクセスが可能になる
- **場所**: `aws_lb.nlb` の `internal` パラメータ

### 【設定ミス4】NLBターゲットグループのヘルスチェック設定
- **問題**: TCPプロトコルのNLBターゲットグループでHTTPヘルスチェックを使用
- **影響**: ヘルスチェックが正常に動作しない可能性
- **場所**: `aws_lb_target_group.nlb_tg` の `health_check.protocol`

### 【設定ミス5】CloudFrontのセキュリティ設定
- **問題**: オリジンとの通信でHTTPを使用し、ビューアーでHTTPSを強制していない
- **影響**: 通信の暗号化が不十分でセキュリティリスクが存在
- **場所**: `aws_cloudfront_distribution.main` の `origin_protocol_policy` と `viewer_protocol_policy`

## デプロイ方法

```bash
cd scenarios/07-cloudfront-nlb-alb-problematic
terraform init
terraform plan
terraform apply
```

## 必要な前提条件

- AWS CLI設定済み
- 指定したリージョンにEC2キーペアが存在すること
- 適切なIAM権限

## 注意事項

このシナリオは学習・検証目的で作成されており、本番環境では使用しないでください。含まれている設定ミスにより、セキュリティリスクや可用性の問題が発生します。

## 学習ポイント

各設定ミスを特定し、適切な修正方法を検討してください：
1. 高可用性のためのマルチAZ配置
2. 最小権限の原則に基づくセキュリティグループ設定
3. 適切なロードバランサー配置
4. プロトコルに応じたヘルスチェック設定
5. エンドツーエンドの暗号化設定