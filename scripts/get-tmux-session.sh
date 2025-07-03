#!/bin/bash
# tmuxセッション名を取得する汎用スクリプト
# 
# 戻り値:
#   - tmuxセッション内: セッション名 (例: "my-project")
#   - tmuxセッション外: "non-tmux"
#   - エラー時: "unknown-tmux"

if [ -n "$TMUX" ]; then
    # $TMUX環境変数が存在する = tmuxセッション内
    session_name=$(tmux display-message -p '#S' 2>/dev/null)
    if [ -n "$session_name" ]; then
        echo "$session_name"
    else
        # tmux内だがセッション名取得失敗
        echo "unknown-tmux"
    fi
else
    # $TMUX環境変数が存在しない = tmuxセッション外
    echo "non-tmux"
fi