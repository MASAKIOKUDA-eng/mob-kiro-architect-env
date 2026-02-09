# 検証ガイド

## 目的

4つのシナリオを比較して、ログ出力の重要性とセキュリティ設定の影響を理解する。

## 検証の流れ

### ステップ1: 環境のデプロイ

```bash
# シナリオ1: 問題あり + ログなし
cd scenarios/01-problematic-no-logs
terraform init && terraform apply -auto-approve

# シナリオ2: 改善済み + ログなし
cd ../02-improved-no-logs
terraform init && terraform apply -auto-approve

# シナリオ3: 問題あり + ログあり
cd ../03-problematic-with-logs
terraform init && terraform apply -auto-approve

# シナリオ4: 改善済み + ログあり
cd ../04-improved-with-logs
terraform init && terraform apply -auto-approve
```

### ステップ2: 基本動作確認

各シナリオで以下を確認：

```bash
# Webサーバーへのアクセス
S1_IP=$(cd scenarios/01-problematic-no-logs && terraform output -raw instance_public_ip)
S2_IP=$(cd scenarios/02-improved-no-logs && terraform output -raw instance_public_ip)
S3_IP=$(cd scenarios/03-problematic-with-logs && terraform output -raw instance_public_ip)
S4_IP=$(cd scenarios/04-improved-with-logs && terraform output -raw instance_public_ip)

curl http://$S1_IP  # タイムアウト（NACL問題）
curl http://$S2_IP  # 成功
curl http://$S3_IP  # タイムアウト（NACL問題）
curl http://$S4_IP  # 成功
```

## 検証シナリオ

### 検証A: NACL設定ミスのトラブルシューティング

#### シナリオ1（ログなし）での調査

```bash
# 1. 問題発生
curl http://$S1_IP
# タイムアウト...

# 2. 手動で調査開始
# セキュリティグループ確認
aws ec2 describe-security-groups --group-ids <sg-id>
# → 問題なし（全開放だが通信は許可）

# NACL確認
aws ec2 describe-network-acls --network-acl-ids <nacl-id>
# → エフェメラルポートがブロックされていることを発見

# 所要時間: 1-2時間
```

#### シナリオ3（ログあり）での調査

```bash
# 1. 問題発生
curl http://$S3_IP
# タイムアウト...

# 2. VPCフローログで即座に確認
aws logs tail /aws/vpc/devops-validation-s3/flow-logs --follow

# 出力例:
# 2 123456789012 eni-xxx 203.0.113.1 10.0.1.10 12345 80 6 1 40 1234567890 1234567891 REJECT OK

# REJECTが見つかる → NACLの問題と即座に特定

# 所要時間: 5-10分
```

**結果**: ログありの方が10倍以上速く問題を特定できる

### 検証B: 不正アクセスの検知

#### シナリオ1（ログなし）

```bash
# 不正アクセスを試行
nmap -p 1-1000 $S1_IP

# 結果: 証跡なし、調査不可能
# セキュリティグループが全開放なので侵入可能
```

#### シナリオ3（ログあり）

```bash
# 不正アクセスを試行
nmap -p 1-1000 $S3_IP

# VPCフローログで検知
aws logs tail /aws/vpc/devops-validation-s3/flow-logs --follow

# CloudWatch Logs Insightsでクエリ
aws logs start-query \
  --log-group-name /aws/vpc/devops-validation-s3/flow-logs \
  --start-time $(date -d '1 hour ago' +%s) \
  --end-time $(date +%s) \
  --query-string 'fields @timestamp, srcAddr, dstPort, action | filter action = "ACCEPT" and dstPort > 1000 | stats count() by srcAddr | sort count desc'

# 結果: 不正アクセス元のIPアドレスを特定可能
```

**結果**: ログがあれば不正アクセスを検知・追跡できる

### 検証C: パフォーマンス問題の調査

#### シナリオ2（ログなし）

```bash
# 負荷をかける
ab -n 1000 -c 10 http://$S2_IP/

# CloudWatch基本メトリクスのみ
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=<instance-id> \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average

# 結果: CPU使用率のみ、詳細不明
```

#### シナリオ4（ログあり）

```bash
# 負荷をかける
ab -n 1000 -c 10 http://$S4_IP/

# 詳細メトリクス確認
aws cloudwatch get-metric-statistics \
  --namespace devops-validation-s4/EC2 \
  --metric-name mem_used_percent \
  --dimensions Name=InstanceId,Value=<instance-id> \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 60 \
  --statistics Average

# アプリケーションログ確認
aws logs tail /aws/devops-validation-s4/application --follow

# 結果: CPU、メモリ、ディスク、アプリケーションログすべて確認可能
```

**結果**: 詳細ログがあれば根本原因を特定できる

### 検証D: セキュリティ監査

#### シナリオ1/2（ログなし）

```bash
# 過去1週間のアクセス履歴を確認したい
# → 不可能（ログなし）

# コンプライアンス要件:
# - 誰がいつアクセスしたか
# - どのような操作を行ったか
# - 異常なアクセスパターンはないか

# 結果: すべて不明、監査不合格
```

#### シナリオ3/4（ログあり）

```bash
# VPCフローログで全アクセスを確認
aws logs filter-log-events \
  --log-group-name /aws/vpc/devops-validation-s3/flow-logs \
  --start-time $(date -d '7 days ago' +%s)000 \
  --filter-pattern '[version, account, eni, source, destination, srcport, destport="80", protocol, packets, bytes, windowstart, windowend, action="ACCEPT", flowlogstatus]'

# アプリケーションログで操作履歴を確認
aws logs filter-log-events \
  --log-group-name /aws/devops-validation-s3/application \
  --start-time $(date -d '7 days ago' +%s)000

# 結果: 完全な監査証跡、コンプライアンス準拠
```

**結果**: ログがあればコンプライアンス要件を満たせる

## コスト分析

### 月額コスト比較

```bash
# 各シナリオのコスト見積もりを確認
cd scenarios/01-problematic-no-logs && terraform output cost_estimate
cd scenarios/02-improved-no-logs && terraform output cost_estimate
cd scenarios/03-problematic-with-logs && terraform output cost_estimate
cd scenarios/04-improved-with-logs && terraform output cost_estimate
```

### ROI計算

```
ログ追加コスト: $11/月

削減できるコスト:
- トラブルシューティング時間: 2時間 → 10分 (1.8時間削減)
- エンジニア時給: $50
- 月間インシデント: 2回

削減額 = 1.8時間 × $50 × 2回 = $180/月

ROI = ($180 - $11) / $11 × 100 = 1,536%
```

**結論**: ログへの投資は圧倒的にROIが高い

## Well-Architected評価

### 評価シート

各シナリオをWell-Architectedフレームワークで評価：

```bash
# シナリオ1
運用の優秀性: ❌ (0/10)
セキュリティ: ❌ (2/10)
信頼性: ❌ (3/10)
パフォーマンス効率: ❌ (2/10)
コスト最適化: ⚠️ (5/10)
総合スコア: 12/50 (24%)

# シナリオ2
運用の優秀性: ⚠️ (5/10)
セキュリティ: ✅ (9/10)
信頼性: ⚠️ (6/10)
パフォーマンス効率: ⚠️ (5/10)
コスト最適化: ✅ (8/10)
総合スコア: 33/50 (66%)

# シナリオ3
運用の優秀性: ⚠️ (6/10)
セキュリティ: ❌ (3/10)
信頼性: ⚠️ (5/10)
パフォーマンス効率: ✅ (8/10)
コスト最適化: ⚠️ (6/10)
総合スコア: 28/50 (56%)

# シナリオ4
運用の優秀性: ✅ (9/10)
セキュリティ: ✅ (10/10)
信頼性: ✅ (9/10)
パフォーマンス効率: ✅ (9/10)
コスト最適化: ✅ (9/10)
総合スコア: 46/50 (92%)
```

## 学習ポイント

### 1. ログの重要性

- **問題検知**: ログがないと問題の存在すら気づかない
- **原因特定**: ログがあれば根本原因を迅速に特定
- **予防**: ログ分析でトレンドを把握し、問題を予防

### 2. セキュリティの基本

- **最小権限の原則**: 必要最小限のアクセスのみ許可
- **多層防御**: セキュリティグループ、NACL、暗号化を組み合わせ
- **監査証跡**: すべての操作をログに記録

### 3. コストと価値のバランス

- **安いだけでは不十分**: S1は最安だが問題多数
- **適切な投資**: S4は最高額だが価値も最大
- **ROI重視**: ログへの投資は高いROI

## まとめ

### 推奨構成

| 環境 | 推奨シナリオ | 理由 |
|------|------------|------|
| 本番 | S4 | 完全な可観測性とセキュリティ |
| ステージング | S4 or S2 | 本番同等 or コスト削減版 |
| 開発 | S2 | セキュリティ確保、ログは任意 |
| 検証 | 全て | 学習目的 |

### 次のステップ

1. 各シナリオを実際にデプロイ
2. 検証シナリオA-Dを実行
3. コスト分析を実施
4. Well-Architected評価を記録
5. 学習内容をドキュメント化

## クリーンアップ

```bash
# 全シナリオを削除
cd scenarios/01-problematic-no-logs && terraform destroy -auto-approve
cd scenarios/02-improved-no-logs && terraform destroy -auto-approve
cd scenarios/03-problematic-with-logs && terraform destroy -auto-approve
cd scenarios/04-improved-with-logs && terraform destroy -auto-approve
```