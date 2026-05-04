#!/bin/bash
# ============================================================
# 各SkillディレクトリをDevOps Agent用のzipファイルに変換
# zipのルートにSKILL.mdが配置される形式で作成
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/zips"

mkdir -p "$OUTPUT_DIR"

for skill_dir in "$SCRIPT_DIR"/*/; do
  # zips/ ディレクトリ自体はスキップ
  dir_name=$(basename "$skill_dir")
  if [ "$dir_name" = "zips" ]; then
    continue
  fi

  # SKILL.md が存在するディレクトリのみ処理
  if [ -f "$skill_dir/SKILL.md" ]; then
    zip_name="${dir_name}.zip"
    echo "Creating: $zip_name"
    
    # ディレクトリの中に入ってzipを作成（ルートにSKILL.mdが来る）
    (cd "$skill_dir" && zip -r "$OUTPUT_DIR/$zip_name" .)
    
    echo "  -> $OUTPUT_DIR/$zip_name"
  fi
done

echo ""
echo "=== 完了 ==="
echo "作成されたzipファイル:"
ls -la "$OUTPUT_DIR"/*.zip 2>/dev/null
echo ""
echo "各zipをAWSコンソールのDevOps Agent > Skills > スキルの追加 > スキルのアップロードからアップロードしてください。"
