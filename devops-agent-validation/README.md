# AWS DevOps Agent 検証環境

AWS Well-Architectedフレームワークに基づいた、よくある設定ミスやトラブルを検証するための環境

## 検証観点

### 1. ネットワーク観点（3つの検証項目）

#### 検証1: セキュリティグループの過度な開放
- **問題**: 0.0.0.0/0への全ポート開放
- **影響**: 不正アクセスのリスク増大
- **Well-Architected**: セキュリティの柱 - ネットワーク保護

#### 検証2: NACLの設定ミス
- **問題**: インバウンド許可だがアウトバウンド（エフェメラルポート）拒否
- **影響**: 通信が確立できない
- **Well-Architected**: 信頼性の柱 - ネットワーク設計

#### 検証3: VPCエンドポイント未設定
- **問題**: AWSサービスへのアクセスがインターネット経由
- **影響**: セキュリティリスク、コスト増加、レイテンシ増加
- **Well-Architected**: コスト最適化、セキュリティの柱

### 2. サーバー観点（3つの検証項目）

#### 検証1: IAMロール未設定
- **問題**: ハードコードされた認証情報の使用
- **影響**: 認証情報漏洩リスク、セキュリティ侵害
- **Well-Architected**: セキュリティの柱 - ID管理

#### 検証2: パッチ未適用とSSM管理の欠如
- **問題**: 古いAMI使用、SSM Agentの未設定
- **影響**: 脆弱性の放置、運用管理の困難
- **Well-Architected**: 運用の優秀性、セキュリティの柱

#### 検証3: 詳細モニタリング無効化
- **問題**: CloudWatch詳細メトリクス無効、ログ収集なし
- **影響**: 問題検知の遅延、トラブルシューティング困難
- **Well-Architected**: 運用の優秀性 - 可観測性

### 3. ストレージ観点（3つの検証項目）

#### 検証1: S3バケットのパブリックアクセス許可
- **問題**: パブリックアクセスブロック無効、バージョニング無効
- **影響**: データ漏洩リスク、誤削除時の復旧不可
- **Well-Architected**: セキュリティの柱 - データ保護

#### 検証2: EBSボリューム暗号化無効
- **問題**: 保管時の暗号化なし
- **影響**: データ漏洩リスク、コンプライアンス違反
- **Well-Architected**: セキュリティの柱 - データ保護

#### 検証3: バックアップ設定の欠如
- **問題**: AWS Backup未設定、スナップショット自動化なし
- **影響**: データ損失リスク、復旧不可
- **Well-Architected**: 信頼性の柱 - バックアップ

## ディレクトリ構造

```
devops-agent-validation/
├── README.md                           # このファイル
├── scenarios/
│   ├── 01-problematic/                # 問題のある環境
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── 02-improved/                   # 改善された環境
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   └── 03-comparison/                 # 比較検証環境
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── README.md
└── docs/
    ├── issues-checklist.md            # 問題点チェックリスト
    └── remediation-guide.md           # 改善ガイド
```

## 使用方法

### 1. 問題のある環境をデプロイ

```bash
cd scenarios/01-problematic
terraform init
terraform plan
terraform apply

# 問題点を確認
terraform output issues_summary
```

### 2. 改善された環境をデプロイ

```bash
cd scenarios/02-improved
terraform init
terraform plan
terraform apply

# 改善点を確認
terraform output improvements_summary
```

### 3. 比較検証

```bash
cd scenarios/03-comparison
terraform init
terraform plan
terraform apply

# 両環境を並行デプロイして比較
terraform output comparison_report
```

## 検証手順

### ネットワーク検証

1. **セキュリティグループ検証**
   ```bash
   # 問題のある環境
   aws ec2 describe-security-groups --group-ids <sg-id>
   
   # 改善された環境
   aws ec2 describe-security-groups --group-ids <sg-id>
   ```

2. **NACL検証**
   ```bash
   # 通信テスト
   curl http://<instance-ip>
   ```

3. **VPCエンドポイント検証**
   ```bash
   # S3アクセスのルート確認
   aws ec2 describe-route-tables
   ```

### サーバー検証

1. **IAMロール検証**
   ```bash
   # インスタンスメタデータ確認
   curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
   ```

2. **SSM検証**
   ```bash
   # SSM経由でコマンド実行
   aws ssm send-command --instance-ids <instance-id> --document-name "AWS-RunShellScript"
   ```

3. **モニタリング検証**
   ```bash
   # CloudWatchメトリクス確認
   aws cloudwatch get-metric-statistics --namespace AWS/EC2 --metric-name CPUUtilization
   ```

### ストレージ検証

1. **S3セキュリティ検証**
   ```bash
   # パブリックアクセス設定確認
   aws s3api get-public-access-block --bucket <bucket-name>
   
   # バージョニング確認
   aws s3api get-bucket-versioning --bucket <bucket-name>
   ```

2. **EBS暗号化検証**
   ```bash
   # ボリューム暗号化状態確認
   aws ec2 describe-volumes --volume-ids <volume-id>
   ```

3. **バックアップ検証**
   ```bash
   # バックアッププラン確認
   aws backup list-backup-plans
   ```

## コスト見積もり

### 問題のある環境（月額）
- EC2 (t3.micro): ~$8
- EBS (20GB): ~$2
- S3 (最小): ~$0.50
- データ転送: ~$5
- **合計**: ~$15.50/月

### 改善された環境（月額）
- EC2 (t3.micro): ~$8
- EBS (20GB, 暗号化): ~$2
- S3 (最小, バージョニング): ~$1
- VPCエンドポイント: ~$7
- CloudWatch詳細メトリクス: ~$3
- AWS Backup: ~$2
- **合計**: ~$23/月

**差額**: ~$7.50/月（セキュリティと信頼性の向上のため）

## Well-Architected 5つの柱との対応

| 柱 | 問題のある環境 | 改善された環境 |
|---|---|---|
| **運用の優秀性** | ❌ SSM未設定<br>❌ ログ収集なし | ✅ SSM有効<br>✅ CloudWatch統合 |
| **セキュリティ** | ❌ 過度な開放<br>❌ 暗号化なし<br>❌ IAMロールなし | ✅ 最小権限<br>✅ 暗号化有効<br>✅ IAMロール使用 |
| **信頼性** | ❌ バックアップなし<br>❌ シングルAZ | ✅ 自動バックアップ<br>✅ マルチAZ対応 |
| **パフォーマンス効率** | ❌ 詳細モニタリングなし | ✅ 詳細メトリクス有効 |
| **コスト最適化** | ⚠️ 不要なデータ転送 | ✅ VPCエンドポイント使用 |

## トラブルシューティング

### よくあるエラー

1. **NACL設定ミスによる通信不可**
   - 症状: HTTPリクエストがタイムアウト
   - 原因: エフェメラルポートのアウトバウンド拒否
   - 解決: NACLのアウトバウンドルール修正

2. **IAMロール未設定によるアクセス拒否**
   - 症状: AWS API呼び出しで認証エラー
   - 原因: インスタンスプロファイル未設定
   - 解決: IAMロールをアタッチ

3. **S3パブリックアクセスによるデータ漏洩**
   - 症状: 意図しないデータ公開
   - 原因: パブリックアクセスブロック無効
   - 解決: パブリックアクセスブロック有効化

## 参考資料

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [AWS Security Best Practices](https://docs.aws.amazon.com/security/)
- [VPC Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html)
- [EC2 Best Practices](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-best-practices.html)
- [S3 Security Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)