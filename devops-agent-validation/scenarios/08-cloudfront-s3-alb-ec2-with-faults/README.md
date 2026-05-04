# シナリオ8: CloudFront + S3 + ALB + EC2 障害注入・復旧検証シナリオ

## ペルソナ

**中小企業のWebサービス運営会社**
- 社員50名程度のSaaS企業
- 自社Webサービスをフロントエンド（S3 + CloudFront）とバックエンドAPI（ALB + EC2）で運用
- 専任のインフラエンジニアは1名、開発者がインフラも兼務
- CloudWatch Logsでログ収集は実施しているが、アラーム設定は最低限

## 構成概要

```
Internet → CloudFront → S3 (静的コンテンツ)
                      → ALB → EC2 (APIサーバー x2)
                              ↓
                         CloudWatch Logs
```

### コンポーネント
- **CloudFront**: CDN（S3オリジン + ALBオリジン）
- **S3**: 静的Webサイトホスティング（HTML/CSS/JS）
- **ALB**: APIリクエストのロードバランシング
- **EC2 (x2)**: バックエンドAPIサーバー（Node.js想定）
- **CloudWatch Logs**: アプリケーションログ、アクセスログ、VPC Flow Logs

## 注入されている障害（8つ）

### カテゴリ1: ネットワーク・接続性の問題

| # | 障害 | 影響 | 検知手段 |
|---|------|------|----------|
| 1 | ALBセキュリティグループでEC2からのヘルスチェック応答ポート（エフェメラルポート）が未許可 | ヘルスチェック失敗 → ターゲットunhealthy | ALB TargetResponseTime, UnHealthyHostCount |
| 2 | EC2セキュリティグループのアウトバウンドでHTTPS(443)のみ許可（HTTP 80未許可） | EC2からの外部API呼び出し失敗、パッケージ更新不可 | アプリケーションログのconnection timeout |

### カテゴリ2: アプリケーション・サーバーの問題

| # | 障害 | 影響 | 検知手段 |
|---|------|------|----------|
| 3 | EC2のディスク容量不足（/var/log が肥大化するcronジョブ） | ログ書き込み失敗 → アプリケーションクラッシュ | CloudWatch DiskSpaceUtilization, アプリログ |
| 4 | ALBヘルスチェックパスが /health だが、アプリは /api/health で応答 | 全ターゲットunhealthy → 503エラー | ALB UnHealthyHostCount, 5xxエラー率 |

### カテゴリ3: CDN・静的コンテンツの問題

| # | 障害 | 影響 | 検知手段 |
|---|------|------|----------|
| 5 | S3バケットポリシーでCloudFrontのOAC/OAIからのアクセスを拒否 | 静的コンテンツ403エラー | CloudFront 4xxErrorRate |
| 6 | CloudFrontのキャッシュTTLが86400秒（24時間）で、デプロイ後も古いコンテンツ配信 | デプロイ反映遅延 | ユーザー報告（メトリクスでは検知困難） |

### カテゴリ4: 監視・運用の問題

| # | 障害 | 影響 | 検知手段 |
|---|------|------|----------|
| 7 | CloudWatch Agentの設定ミス（ログファイルパスが間違い） | ログが収集されない → 障害調査不可 | CloudWatch Logs IncomingLogEvents = 0 |
| 8 | Auto Scaling のクールダウン期間が600秒（10分）で、スケールアウト遅延 | 負荷急増時にレスポンス劣化 | ALB TargetResponseTime, RequestCount |

## 復旧シナリオ

各障害に対する復旧手順は `skills/` ディレクトリに Kiro Skills として定義されています。

## デプロイ方法

```bash
cd 08-cloudfront-s3-alb-ec2-with-faults
terraform init
terraform plan
terraform apply
```

## 検証の進め方

1. `terraform apply` でインフラをデプロイ
2. AWS DevOps Agent に障害の調査を依頼
3. Agent が各障害を特定できるか確認
4. Skills を使って復旧手順を実行
5. 復旧後の状態を確認

## クリーンアップ

```bash
terraform destroy
```

## 注意事項

⚠️ **この環境は検証目的のみです。本番環境では絶対に使用しないでください。**
