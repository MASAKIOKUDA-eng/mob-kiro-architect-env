# シナリオ1: 問題のある環境

このシナリオは、意図的に複数のセキュリティ問題と設定ミスを含む環境です。

## 含まれる問題

### ネットワーク観点（3つ）

1. **セキュリティグループの過度な開放**
   - すべてのポート（0-65535）を0.0.0.0/0に開放
   - TCP、UDP、ICMPすべて開放
   - 影響: 不正アクセスのリスク極大

2. **NACLの設定ミス**
   - エフェメラルポート（1024-65535）のアウトバウンドを拒否
   - 影響: HTTPレスポンスが返せない、通信が確立できない

3. **VPCエンドポイント未設定**
   - S3、SSM、CloudWatchへのアクセスがインターネット経由
   - 影響: セキュリティリスク、コスト増加、レイテンシ増加

### サーバー観点（3つ）

1. **IAMロール未設定**
   - インスタンスプロファイルなし
   - ユーザーデータに認証情報をハードコード
   - 影響: 認証情報漏洩リスク

2. **パッチ未適用とSSM管理の欠如**
   - 古いAMI（2023年1月）を使用
   - SSM Agentの設定なし
   - 影響: 脆弱性の放置、運用管理困難

3. **詳細モニタリング無効化**
   - CloudWatch詳細メトリクス無効
   - CloudWatch Agentなし
   - 影響: 問題検知の遅延

### ストレージ観点（3つ）

1. **S3バケットのパブリックアクセス許可**
   - パブリックアクセスブロックすべて無効
   - バージョニング無効
   - 影響: データ漏洩リスク、誤削除時の復旧不可

2. **EBSボリューム暗号化無効**
   - 保管時の暗号化なし
   - ルートボリュームも暗号化なし
   - 影響: データ漏洩リスク

3. **バックアップ設定の欠如**
   - AWS Backup未設定
   - スナップショット自動化なし
   - 影響: データ損失リスク

## デプロイ方法

```bash
cd scenarios/01-problematic
terraform init
terraform plan
terraform apply
```

## 検証方法

### 1. セキュリティグループの確認

```bash
# セキュリティグループのルールを確認
aws ec2 describe-security-groups \
  --group-ids $(terraform output -raw security_group_id) \
  --query 'SecurityGroups[0].IpPermissions'

# 期待される結果: すべてのポートが0.0.0.0/0に開放されている
```

### 2. NACL問題の確認

```bash
# Webサーバーへのアクセスを試行
curl -v http://$(terraform output -raw instance_public_ip)

# 期待される結果: タイムアウトまたは接続失敗
# 理由: NACLがエフェメラルポートをブロックしているため
```

### 3. IAMロールの確認

```bash
# インスタンスのIAMロールを確認
aws ec2 describe-instances \
  --instance-ids $(terraform output -raw instance_id) \
  --query 'Reservations[0].Instances[0].IamInstanceProfile'

# 期待される結果: null（IAMロールなし）
```

### 4. S3パブリックアクセスの確認

```bash
# パブリックアクセスブロック設定を確認
aws s3api get-public-access-block \
  --bucket $(terraform output -raw s3_bucket_name)

# 期待される結果: すべてfalse

# パブリックファイルへのアクセスを試行
curl $(terraform output -raw s3_public_url)

# 期待される結果: ファイル内容が表示される（パブリックアクセス可能）
```

### 5. EBS暗号化の確認

```bash
# EBSボリュームの暗号化状態を確認
aws ec2 describe-volumes \
  --volume-ids $(terraform output -raw ebs_volume_id) \
  --query 'Volumes[0].Encrypted'

# 期待される結果: false（暗号化されていない）
```

## Well-Architected違反の確認

```bash
# すべての違反を表示
terraform output well_architected_violations
```

## クリーンアップ

```bash
terraform destroy
```

## 注意事項

⚠️ **この環境は検証目的のみです。本番環境では絶対に使用しないでください。**

- セキュリティグループが全開放されています
- 認証情報がハードコードされています
- データが暗号化されていません
- バックアップがありません

これらの問題は意図的に含まれており、改善シナリオ（02-improved）で修正されます。