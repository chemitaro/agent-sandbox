#!/bin/bash
# Sandbox設定ファイル移行スクリプト
# 旧形式から新形式への自動変換

echo "🔄 Sandbox設定ファイルの移行を開始します..."

if [ ! -f "sandbox.config" ]; then
    echo "❌ sandbox.configが見つかりません"
    exit 1
fi

# バックアップを作成
cp sandbox.config sandbox.config.backup
echo "✅ バックアップを作成しました: sandbox.config.backup"

# 一時ファイルを作成
TMP_FILE=$(mktemp)

# 設定を変換
while IFS= read -r line; do
    # コメント行や空行はそのまま出力
    if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "$line" ]]; then
        echo "$line" >> "$TMP_FILE"
    # github_token を GH_TOKEN に変換
    elif [[ "$line" =~ ^[[:space:]]*github_token[[:space:]]*= ]]; then
        echo "$line" | sed 's/github_token/GH_TOKEN/' >> "$TMP_FILE"
    # source_path を SOURCE_PATH に変換
    elif [[ "$line" =~ ^[[:space:]]*source_path[[:space:]]*= ]]; then
        echo "$line" | sed 's/source_path/SOURCE_PATH/' >> "$TMP_FILE"
    # timezone を TZ に変換
    elif [[ "$line" =~ ^[[:space:]]*timezone[[:space:]]*= ]]; then
        echo "$line" | sed 's/timezone/TZ/' >> "$TMP_FILE"
    else
        echo "$line" >> "$TMP_FILE"
    fi
done < sandbox.config

# 新しい設定で上書き
mv "$TMP_FILE" sandbox.config

echo "✅ 設定ファイルを新形式に移行しました"
echo ""
echo "変更内容:"
echo "  github_token → GH_TOKEN"
echo "  source_path → SOURCE_PATH"
echo "  timezone → TZ"
echo ""
echo "注意: GitHubトークンは必須設定からオプション設定に変更されました"
echo ""
echo "問題がある場合は sandbox.config.backup から復元できます"