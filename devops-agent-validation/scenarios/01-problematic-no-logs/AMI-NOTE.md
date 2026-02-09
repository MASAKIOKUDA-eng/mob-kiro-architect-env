# AMIに関する注記

## 検証環境での対応

このシナリオでは、「古いAMIの使用」という問題を検証するために、以下のアプローチを取っています。

### 実装方法

```hcl
data "aws_ami" "old_amazon_linux" {
  most_recent = true  # 検証環境では最新を使用
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}
```

### 理由

1. **AMIの可用性**: 古い特定バージョンのAMIは、リージョンやタイミングによって利用できない場合があります
2. **検証の目的**: このシナリオの主な目的は、AMIのバージョン管理の重要性を理解することです
3. **実用性**: 検証環境が確実にデプロイできることを優先しています

## 実際の問題シナリオ

本番環境で「古いAMI」の問題を再現する場合：

### 方法1: 特定バージョンを指定

```hcl
data "aws_ami" "old_amazon_linux" {
  most_recent = false
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.0.20230119.1-x86_64-gp2"]  # 古い特定バージョン
  }
}
```

### 方法2: 日付でフィルタ

```hcl
data "aws_ami" "old_amazon_linux" {
  most_recent = false
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.0.2023*-x86_64-gp2"]  # 2023年のAMI
  }
  
  filter {
    name   = "creation-date"
    values = ["2023-01-*"]  # 2023年1月のAMI
  }
}
```

### 方法3: AMI IDを直接指定

```hcl
resource "aws_instance" "problematic" {
  ami = "ami-0c55b159cbfafe1f0"  # 古い特定のAMI ID
  # ...
}
```

## 問題点の説明

### なぜ古いAMIが問題なのか

1. **セキュリティパッチ未適用**
   - CVE（Common Vulnerabilities and Exposures）への対応がない
   - 既知の脆弱性が残っている

2. **コンプライアンス違反**
   - 多くの規制で最新のセキュリティパッチ適用が要求される
   - 監査で指摘される可能性

3. **サポート終了リスク**
   - 古いバージョンはサポートが終了している可能性
   - 問題発生時にベンダーサポートを受けられない

## ベストプラクティス

### 推奨: 常に最新のAMIを使用

```hcl
data "aws_ami" "latest_amazon_linux" {
  most_recent = true  # 常に最新
  owners      = ["amazon"]
  
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]  # Amazon Linux 2023
  }
}
```

### 自動更新の実装

```hcl
# AWS Systems Manager Patch Managerを使用
resource "aws_ssm_patch_baseline" "production" {
  name             = "production-baseline"
  operating_system = "AMAZON_LINUX_2"
  
  approval_rule {
    approve_after_days = 7
    compliance_level   = "CRITICAL"
    
    patch_filter {
      key    = "CLASSIFICATION"
      values = ["Security", "Bugfix"]
    }
  }
}
```

## まとめ

- **検証環境**: 最新のAMIを使用（デプロイの確実性優先）
- **本番環境**: 常に最新のAMIを使用し、自動パッチ適用を設定
- **問題の理解**: AMIのバージョン管理がセキュリティに直結することを認識

このシナリオは、AMI管理の重要性を理解するための教材として設計されています。