# AWS DevOps Agent 検証環境

AWS Well-Architectedフレームワークに基づいた、ログ出力の有無による比較検証環境

## シナリオ構成

### シナリオ1: 問題のある環境（ログ出力なし）
- セキュリティ問題を含む
- CloudWatch Logs: ❌ 無効
- VPCフローログ: ❌ 無効
- **用途**: 問題のある環境でログがない場合のトラブルシューティングの困難さを体験

### シナリオ2: 改善された環境（ログ出力なし）
- セキュリティ問題を修正
- CloudWatch Logs: ❌ 無効
- VPCフローログ: ❌ 無効
- **用途**: セキュリティは改善されているがログがない環境

### シナリオ3: 問題のある環境（ログ出力あり）
- セキュリティ問題を含む
- CloudWatch Logs: ✅ 有効
- VPCフローログ: ✅ 有効
- **用途**: 問題のある環境でもログがあれば問題を特定しやすいことを確認

### シナリオ4: 改善された環境（ログ出力あり）
- セキュリティ問題を修正
- CloudWatch Logs: ✅ 有効
- VPCフローログ: ✅ 有効
- **用途**: 理想的な環境（セキュリティ + 可観測性）

### シナリオ5: ECR/Lambda 問題のある環境
- ECR: イメージスキャン無効、ミュータブルタグ、過度に開放されたポリシー
- Lambda: プレーンテキストのシークレット、過剰な権限、認証なしのFunction URL
- **用途**: コンテナとサーバーレスのセキュリティ問題を検証

### シナリオ6: ECR/Lambda 改善された環境
- ECR: イメージスキャン有効、イミュータブルタグ、KMS暗号化、ライフサイクルポリシー
- Lambda: Secrets Manager統合、最小権限IAM、DLQ、X-Rayトレーシング、VPC設定
- **用途**: コンテナとサーバーレスのベストプラクティスを実装

## 検証観点

### 1. ネットワーク観点（3つ）

#### 検証1: セキュリティグループの過度な開放
- **問題**: 0.0.0.0/0への全ポート開放
- **影響**: 不正アクセスのリスク増大
- **Well-Architected**: セキュリティの柱

#### 検証2: NACLの設定ミス
- **問題**: エフェメラルポート拒否による通信不可
- **影響**: サービス停止
- **Well-Architected**: 信頼性の柱

#### 検証3: VPCエンドポイント未設定
- **問題**: インターネット経由のAWSサービスアクセス
- **影響**: コスト増加、セキュリティリスク
- **Well-Architected**: コスト最適化、セキュリティの柱

### 2. サーバー観点（3つ）

#### 検証1: IAMロール未設定
- **問題**: ハードコードされた認証情報
- **影響**: 認証情報漏洩リスク
- **Well-Architected**: セキュリティの柱

#### 検証2: パッチ未適用とSSM管理の欠如
- **問題**: 古いAMI、SSM未設定
- **影響**: 脆弱性の放置
- **Well-Architected**: 運用の優秀性、セキュリティの柱

#### 検証3: 詳細モニタリング無効化
- **問題**: メトリクス収集なし
- **影響**: 問題検知の遅延
- **Well-Architected**: 運用の優秀性

### 3. ストレージ観点（3つ）

#### 検証1: S3バケットのパブリックアクセス許可
- **問題**: パブリックアクセス可能
- **影響**: データ漏洩リスク
- **Well-Architected**: セキュリティの柱

#### 検証2: EBSボリューム暗号化無効
- **問題**: 暗号化なし
- **影響**: データ保護不足
- **Well-Architected**: セキュリティの柱

#### 検証3: バックアップ設定の欠如
- **問題**: バックアップなし
- **影響**: データ損失リスク
- **Well-Architected**: 信頼性の柱

### 4. コンテナ観点（5つ - シナリオ5/6）

#### 検証1: ECRイメージスキャン無効
- **問題**: 脆弱性のあるイメージの検出不可
- **影響**: セキュリティリスク
- **Well-Architected**: セキュリティの柱

#### 検証2: ミュータブルなイメージタグ
- **問題**: タグの上書きによる再現性の欠如
- **影響**: デプロイメントの信頼性低下
- **Well-Architected**: 運用の優秀性の柱

#### 検証3: ECRライフサイクルポリシー未設定
- **問題**: 古いイメージの蓄積
- **影響**: ストレージコスト増加
- **Well-Architected**: コスト最適化の柱

#### 検証4: 過度に開放されたECRポリシー
- **問題**: すべてのAWSアカウントがイメージをプル可能
- **影響**: 不正アクセスリスク
- **Well-Architected**: セキュリティの柱

#### 検証5: ECR暗号化設定なし
- **問題**: カスタマー管理キーによる暗号化なし
- **影響**: データ保護の不足
- **Well-Architected**: セキュリティの柱

### 5. サーバーレス観点（10個 - シナリオ5/6）

#### 検証1: プレーンテキストのシークレット
- **問題**: 環境変数に機密情報を平文保存
- **影響**: 認証情報漏洩リスク
- **Well-Architected**: セキュリティの柱

#### 検証2: 過剰なIAM権限
- **問題**: AdministratorAccess権限の付与
- **影響**: 権限昇格リスク
- **Well-Architected**: セキュリティの柱

#### 検証3: デッドレターキュー未設定
- **問題**: 失敗した実行の損失
- **影響**: データ損失、デバッグ困難
- **Well-Architected**: 信頼性の柱

#### 検証4: X-Rayトレーシング無効
- **問題**: 可観測性の欠如
- **影響**: トラブルシューティング困難
- **Well-Architected**: 運用の優秀性の柱

#### 検証5: 認証なしのFunction URL
- **問題**: パブリックアクセス可能
- **影響**: 不正利用リスク
- **Well-Architected**: セキュリティの柱

#### 検証6: 無制限のログ保持
- **問題**: CloudWatch Logsの保持期間未設定
- **影響**: コスト増加
- **Well-Architected**: コスト最適化の柱

#### 検証7: VPC設定なし
- **問題**: ネットワーク分離なし
- **影響**: セキュリティリスク
- **Well-Architected**: セキュリティの柱

#### 検証8: バージョニング・エイリアスなし
- **問題**: デプロイメント管理の欠如
- **影響**: ロールバック困難
- **Well-Architected**: 運用の優秀性の柱

#### 検証9: 過剰なタイムアウト設定
- **問題**: 900秒のタイムアウト
- **影響**: 暴走関数によるコスト増加
- **Well-Architected**: コスト最適化の柱

#### 検証10: 過剰なメモリ割り当て
- **問題**: 10GBのメモリ設定
- **影響**: 不要なコスト
- **Well-Architected**: コスト最適化の柱

## ログ出力による比較

| 項目 | ログなし（S1/S2） | ログあり（S3/S4） |
|------|------------------|------------------|
| **問題検知** | 困難 | 容易 |
| **トラブルシューティング** | 時間がかかる | 迅速 |
| **セキュリティ監査** | 不可能 | 可能 |
| **コンプライアンス** | 非準拠 | 準拠 |
| **月額コスト** | ~$15 | ~$25 |

## ディレクトリ構造

```
devops-agent-validation/
├── README.md
├── scenarios/
│   ├── 01-problematic-no-logs/        # 問題あり + ログなし (EC2/S3/VPC)
│   ├── 02-improved-no-logs/           # 改善済み + ログなし (EC2/S3/VPC)
│   ├── 03-problematic-with-logs/      # 問題あり + ログあり (EC2/S3/VPC)
│   ├── 04-improved-with-logs/         # 改善済み + ログあり (EC2/S3/VPC)
│   ├── 05-ecr-lambda-problematic/     # 問題あり (ECR/Lambda)
│   └── 06-ecr-lambda-improved/        # 改善済み (ECR/Lambda)
└── docs/
    ├── comparison-matrix.md           # 比較表
    └── validation-guide.md            # 検証ガイド
```

## 使用方法

### 1. シナリオ1をデプロイ（問題あり + ログなし）

```bash
cd scenarios/01-problematic-no-logs
terraform init
terraform apply
```

### 2. シナリオ2をデプロイ（改善済み + ログなし）

```bash
cd scenarios/02-improved-no-logs
terraform init
terraform apply
```

### 3. シナリオ3をデプロイ（問題あり + ログあり）

```bash
cd scenarios/03-problematic-with-logs
terraform init
terraform apply
```

### 4. シナリオ4をデプロイ（改善済み + ログあり）

```bash
cd scenarios/04-improved-with-logs
terraform init
terraform apply
```

### 5. シナリオ5をデプロイ（ECR/Lambda問題あり）

```bash
cd scenarios/05-ecr-lambda-problematic
terraform init
terraform apply
```

### 6. シナリオ6をデプロイ（ECR/Lambda改善済み）

```bash
cd scenarios/06-ecr-lambda-improved
terraform init
terraform apply
```

## 比較検証の手順

### ステップ1: ログなし環境での問題調査

```bash
# シナリオ1で問題発生
# ログがないため原因特定が困難

# 例: NACLの問題でHTTPアクセスできない
curl http://<instance-ip>  # タイムアウト

# ログがないため、どこで失敗しているか不明
```

### ステップ2: ログあり環境での問題調査

```bash
# シナリオ3で同じ問題発生
# VPCフローログで原因を特定

# VPCフローログを確認
aws logs tail /aws/vpc/devops-validation-s3/flow-logs --follow

# CloudWatch Logsで詳細を確認
aws logs tail /aws/devops-validation-s3/application --follow
```

### ステップ3: コスト比較

```bash
# 各シナリオのコストを確認
terraform output cost_estimate
```

## 検証シナリオ例

### シナリオA: セキュリティインシデント調査

1. **ログなし環境（S1）**: 不正アクセスの痕跡を確認できない
2. **ログあり環境（S3）**: VPCフローログで不正アクセス元を特定

### シナリオB: パフォーマンス問題の調査

1. **ログなし環境（S2）**: メトリクスが不足して原因不明
2. **ログあり環境（S4）**: CloudWatch Logsで詳細な分析が可能

### シナリオC: コンプライアンス監査

1. **ログなし環境（S1/S2）**: 監査証跡なし
2. **ログあり環境（S3/S4）**: すべての操作を追跡可能

## コスト見積もり

### ログなし環境（S1/S2）
- EC2 (t3.micro): ~$8/月
- EBS (20GB): ~$2/月
- S3 (最小): ~$1/月
- **合計**: ~$11/月

### ログあり環境（S3/S4）
- EC2 (t3.micro): ~$8/月
- EBS (20GB): ~$2/月
- S3 (最小): ~$1/月
- CloudWatch Logs: ~$5/月
- VPCフローログ: ~$3/月
- CloudWatch詳細メトリクス: ~$3/月
- **合計**: ~$22/月

**差額**: ~$11/月（可観測性の向上のため）

## Well-Architected評価

| シナリオ | 運用の優秀性 | セキュリティ | 信頼性 | パフォーマンス | コスト |
|---------|------------|------------|--------|--------------|--------|
| S1 | ❌ | ❌ | ❌ | ❌ | ⚠️ |
| S2 | ⚠️ | ✅ | ⚠️ | ⚠️ | ⚠️ |
| S3 | ⚠️ | ❌ | ⚠️ | ✅ | ⚠️ |
| S4 | ✅ | ✅ | ✅ | ✅ | ✅ |

## 推奨事項

1. **本番環境**: シナリオ4（改善済み + ログあり）を推奨
2. **開発環境**: シナリオ2（改善済み + ログなし）でコスト削減可能
3. **検証環境**: すべてのシナリオをデプロイして比較

## 参考資料

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [CloudWatch Logs](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/)
- [VPC Flow Logs](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html)