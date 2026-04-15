---
inclusion: manual
---

# ネットワーク分析スキル

Terraformで構築されたAWSネットワーク構成の問題を分析・検出するスキルです。

## 分析対象

以下のリソースを対象にネットワーク設定ミスを検出します：

- VPC / サブネット構成
- Security Group ルール
- NACL ルール
- Load Balancer（ALB / NLB）設定
- CloudFront Distribution 設定
- Auto Scaling Group 設定
- ルートテーブル関連付け

## 分析手順

### 1. サブネット・AZ分析
- パブリック/プライベートサブネットが異なるAZに分散されているか
- LBに割り当てられたサブネットが同一AZに重複していないか

### 2. Security Group 分析
- 不要なポート（SSH等）が 0.0.0.0/0 に開放されていないか
- ALB/NLBに適切なSGが割り当てられているか
- EC2のSGがLBからのトラフィックのみ許可しているか

### 3. NACL 分析
- インバウンドで許可したトラフィックに対応するエフェメラルポート（1024-65535）のアウトバウンドが許可されているか
- ルール番号の優先順位が意図通りか

### 4. Load Balancer 分析
- NLBが internal/external で意図通りの設定か（CloudFrontからアクセスする場合は external が必要）
- ターゲットグループのヘルスチェックパスが実際に存在するエンドポイントか
- ヘルスチェックプロトコルがターゲットグループのプロトコルと整合しているか

### 5. CloudFront 分析
- origin_protocol_policy が https-only または match-viewer になっているか
- viewer_protocol_policy が redirect-to-https または https-only になっているか
- 必要な Cookie / ヘッダーが転送設定されているか

### 6. ASG 分析
- health_check_grace_period がアプリケーション起動時間より十分長いか（推奨: 300秒以上）
- Launch Template にキーペアが設定されているか（デバッグ用SSH接続が必要な場合）

### 7. ログ・モニタリング分析
- VPC Flow Logs が有効になっているか
- ALB アクセスログが有効になっているか
- CloudFront アクセスログが有効になっているか
- CloudWatch アラームが適切に設定されているか

## 出力フォーマット

分析結果は以下の形式で出力してください：

```
## ネットワーク分析レポート

### 🔴 重大な問題（通信障害を引き起こす）
| # | リソース | 問題 | 影響 | 推奨修正 |

### 🟡 セキュリティ上の問題
| # | リソース | 問題 | 影響 | 推奨修正 |

### 🟢 ベストプラクティス違反
| # | リソース | 問題 | 影響 | 推奨修正 |

### ログ・モニタリング状況
| リソース | ログ有効 | 出力先 | 備考 |
```

## 使い方

チャットで `#network-analysis` を指定した上で、分析対象のTerraformファイルを渡してください。

例：
```
#network-analysis #File scenarios/07-cloudfront-nlb-alb-problematic/main.tf を分析して
```
