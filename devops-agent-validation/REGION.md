# リージョン設定

## デフォルトリージョン

すべてのシナリオは **us-east-1 (バージニア北部)** にデプロイされます。

## リージョンの変更方法

各シナリオの `variables.tf` で変更可能：

```hcl
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"  # ここを変更
}
```

または、デプロイ時に指定：

```bash
terraform apply -var="aws_region=ap-northeast-1"
```

## リージョン別の注意事項

### us-east-1 (バージニア北部) - デフォルト
- 最も多くのサービスが利用可能
- 料金が最も安い
- ELBサービスアカウント: `127311923021`

### ap-northeast-1 (東京)
- 日本からのレイテンシが低い
- 一部サービスの料金が高い
- ELBサービスアカウント: `582318560864`

### その他のリージョン
- VPCエンドポイントのサービス名が異なる場合があります
- ELBサービスアカウントIDが異なります
- 利用可能なAZの数が異なる場合があります

## 確認方法

```bash
# 現在の設定を確認
cd scenarios/01-problematic-no-logs
terraform console
> var.aws_region
"us-east-1"
```

## コスト比較（月額概算）

| リージョン | S1 | S2 | S3 | S4 |
|-----------|----|----|----|----|
| us-east-1 | $11 | $18 | $22 | $29 |
| ap-northeast-1 | $13 | $21 | $26 | $34 |

※ 東京リージョンは約15-20%高い