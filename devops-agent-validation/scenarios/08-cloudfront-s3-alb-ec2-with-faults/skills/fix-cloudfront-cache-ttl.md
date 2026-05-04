---
inclusion: manual
---

# Skill: CloudFront キャッシュTTL修正

## 障害概要

CloudFrontのデフォルトキャッシュTTLが86400秒（24時間）に設定されており、S3にデプロイした新しいコンテンツが即座に反映されない。

## 症状

- S3にファイルをアップロードしても、CloudFront経由では古いコンテンツが返される
- デプロイ後24時間経過しないと新バージョンが配信されない
- メトリクスでは異常が検知されない（正常にキャッシュから配信されているため）

## 根本原因

CloudFront distribution の `default_cache_behavior` で `default_ttl = 86400`（24時間）に設定されている。S3オブジェクトに `Cache-Control` ヘッダーが設定されていない場合、このTTLが適用される。

## 復旧手順

### 1. 緊急対応（キャッシュ無効化）

```bash
# 全キャッシュを無効化
aws cloudfront create-invalidation \
  --distribution-id <DISTRIBUTION_ID> \
  --paths "/*"

# 無効化の進捗確認
aws cloudfront get-invalidation \
  --distribution-id <DISTRIBUTION_ID> \
  --id <INVALIDATION_ID>
```

### 2. TTL設定の修正

```bash
# 現在のディストリビューション設定を取得
aws cloudfront get-distribution-config \
  --id <DISTRIBUTION_ID> > dist-config.json

# ETagを記録（更新時に必要）
ETAG=$(aws cloudfront get-distribution-config --id <DISTRIBUTION_ID> --query 'ETag' --output text)

# dist-config.json を編集して DefaultTTL を変更
# DefaultCacheBehavior.DefaultTTL: 86400 → 300 (5分)
# DefaultCacheBehavior.MaxTTL: 604800 → 3600 (1時間)

# 更新を適用
aws cloudfront update-distribution \
  --id <DISTRIBUTION_ID> \
  --if-match $ETAG \
  --distribution-config file://dist-config-updated.json
```

### 3. Terraform修正

```hcl
# aws_cloudfront_distribution.main の default_cache_behavior を修正
default_cache_behavior {
  # ... 他の設定 ...
  
  min_ttl     = 0
  default_ttl = 300    # 5分に短縮
  max_ttl     = 3600   # 1時間に短縮
}
```

### 4. 推奨: S3オブジェクトに Cache-Control ヘッダーを設定

```bash
# HTMLファイル: キャッシュしない
aws s3 cp index.html s3://<BUCKET>/index.html \
  --cache-control "no-cache, no-store, must-revalidate"

# アセットファイル: バージョニング付きで長期キャッシュ
aws s3 cp assets/style.v2.css s3://<BUCKET>/assets/style.v2.css \
  --cache-control "public, max-age=31536000, immutable"
```

### 5. 復旧確認

```bash
# キャッシュ無効化完了確認
aws cloudfront wait invalidation-completed \
  --distribution-id <DISTRIBUTION_ID> \
  --id <INVALIDATION_ID>

# 新しいコンテンツが配信されることを確認
curl -I https://<CLOUDFRONT_DOMAIN>/index.html
# X-Cache: Miss from cloudfront が返ること
```

## 予防策

- 静的アセットにはファイル名にハッシュを含める（例: `app.abc123.js`）
- HTMLファイルには `Cache-Control: no-cache` を設定
- CI/CDパイプラインにデプロイ後のキャッシュ無効化を組み込む
- CloudFront Functions で動的に Cache-Control を付与する方法も検討
