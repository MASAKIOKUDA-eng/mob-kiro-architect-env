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
│   ├── 01-problematic-no-logs/        # 問題あり + ログなし
│   ├── 02-improved-no-logs/           # 改善済み + ログなし
│   ├── 03-problematic-with-logs/      # 問題あり + ログあり
│   └── 04-improved-with-logs/         # 改善済み + ログあり
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