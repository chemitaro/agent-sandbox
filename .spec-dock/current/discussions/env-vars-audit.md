# Dockerfile / docker-compose.yml の環境変数監査メモ（設定パス系）

最終更新: 2026-01-23

## 調査対象
- Dockerfile / docker-compose.yml で「CLI の設定ディレクトリ（設定ファイル/キャッシュ等）のパス」を直接指定している env var
- 併せて、同種の“ノイズ候補”（未使用の env var 露出など）

## As-Is（リポジトリの現状）

### docker-compose.yml（コンテナ環境変数）
- 設定パス系:
  - `CLAUDE_CONFIG_DIR=/home/node/.claude`
  - `CODEX_CONFIG_DIR=/home/node/.codex`
  - `GEMINI_CONFIG_DIR=/home/node/.gemini`
  - `OPENCODE_CONFIG_DIR=/home/node/.config/opencode`
  - `OPENCODE_DATA_DIR=/home/node/.local/share/opencode`
  - `OPENCODE_CACHE_DIR=/home/node/.cache/opencode`
- その他（“コンテナに渡しているが参照箇所が見当たらない”候補）:
  - `HOST_SANDBOX_PATH`, `HOST_USERNAME`, `HOST_PRODUCT_PATH`, `PRODUCT_NAME`, `PRODUCT_WORK_DIR`

### docker-compose.yml（永続化: bind mount）
以下は env var と無関係に、ホスト側 `.agent-home/` を所定パスにマウントしている（= 設定は“その場所にある”）。
- `./.agent-home/.claude:/home/node/.claude`
- `./.agent-home/.codex:/home/node/.codex`
- `./.agent-home/.gemini:/home/node/.gemini`
- `./.agent-home/.opencode:/home/node/.config/opencode`
- `./.agent-home/.opencode-data:/home/node/.local/share/opencode`
- `./.agent-home/.cache/opencode:/home/node/.cache/opencode`

### Dockerfile（ENV）
- 設定パス系:
  - `ENV CODEX_CONFIG_DIR=/home/node/.codex`
  - `ENV GEMINI_CONFIG_DIR=/home/node/.gemini`
  - `ENV OPENCODE_CONFIG_DIR=/home/node/.config/opencode`
  - `ENV OPENCODE_DATA_DIR=/home/node/.local/share/opencode`
  - `ENV OPENCODE_CACHE_DIR=/home/node/.cache/opencode`

## 公式情報（設定パス/関連 env var の確認）

### Codex（OpenAI）
- デフォルトの状態保存先: `CODEX_HOME`（デフォルト `~/.codex`）
- 設定ファイル: `~/.codex/config.toml`
- 重要ポイント:
  - `CODEX_CONFIG_DIR` は公式の変数名として確認できなかった
  - パスを変えるなら `CODEX_HOME` または CLI オプション（`-c/--config`）が筋

### Claude Code（Anthropic）
- デフォルトの設定ディレクトリ: `~/.claude`
- `CLAUDE_CONFIG_DIR`: 設定ディレクトリを上書きできる（公式に存在）
- 重要ポイント:
  - `CLAUDE_CONFIG_DIR=/home/node/.claude` は “デフォルトと同一” のため冗長

### Gemini CLI（Google）
- ユーザー設定: `~/.gemini/settings.json`（公式ドキュメントに明記）
- 重要ポイント:
  - `GEMINI_CONFIG_DIR` は公式ドキュメント上に存在しない（未対応/別名の可能性が高い）

### OpenCode
- グローバル設定: `~/.config/opencode/opencode.json`（公式ドキュメントに明記）
- `OPENCODE_CONFIG_DIR`: “追加のカスタムディレクトリ”を指定する用途（公式に存在）
- 重要ポイント:
  - `OPENCODE_CONFIG_DIR=/home/node/.config/opencode` は “デフォルトと同一” で冗長（または二重ロードの可能性もあるため、明示しない方が安全）
  - `OPENCODE_DATA_DIR` / `OPENCODE_CACHE_DIR` は公式ドキュメント上に存在しない（未対応/別名の可能性が高い）

## ノイズ候補の判定（削除案）

### 1) 誤り/未対応の可能性が高い（削除推奨）
- `CODEX_CONFIG_DIR`（Codex の公式変数名ではない）
- `GEMINI_CONFIG_DIR`（Gemini CLI のドキュメントに存在しない）
- `OPENCODE_DATA_DIR` / `OPENCODE_CACHE_DIR`（OpenCode のドキュメントに存在しない）

### 2) 公式には存在するが、デフォルトと同じで冗長（削除推奨）
- `CLAUDE_CONFIG_DIR=/home/node/.claude`
- `OPENCODE_CONFIG_DIR=/home/node/.config/opencode`

### 3) Compose 補間には必要だが、コンテナ env としては未使用（削除“検討”）
- `HOST_SANDBOX_PATH`, `HOST_USERNAME`, `HOST_PRODUCT_PATH`, `PRODUCT_NAME`, `PRODUCT_WORK_DIR`
  - 補間（`volumes:` や `working_dir:`）には必要
  - ただし `environment:` でコンテナに渡す必然性は、現状リポジトリ内では見当たらない

## リスク/注意点
- “非公式 env var” に依存していた運用がある場合、削除後に効かなくなる（→ 公式の正しい変数名へ移行が必要）。
- `OPENCODE_CONFIG_DIR` は公式に存在するため、意図的に “カスタムディレクトリ” として使っている場合は削除しない方が良い（ただし現状はデフォルトと同じパスを指しているため、基本は冗長）。

## 追加のノイズ候補（設定パス以外 / 要確認）
このタスク（CHORE-ENV-001）の一次スコープ外だが、“徹底的に洗い出す”観点で列挙する。

- `DEVCONTAINER=true`
  - Dockerfile と docker-compose.yml の両方で設定されている（重複）
- `DOCKER_CONFIG=/home/node/.docker`
  - Docker のデフォルトも通常は `~/.docker`（= `/home/node/.docker`）のため冗長の可能性
  - ただし root 実行時に node の設定を強制したい意図があるなら残す理由になり得る
- `DOCKER_HOST=unix:///var/run/docker.sock`
  - Docker のデフォルトも通常は `/var/run/docker.sock` のため冗長の可能性
  - ただし “docker context が悪さをする環境”対策として明示する価値はある
- `TMUX_SESSION_NAME=non-tmux`
  - リポジトリ内で参照箇所が見当たらない
  - ただしコンテナ内で生成される zsh 設定やプロンプトが参照している可能性があるため要確認
- `NODE_OPTIONS=--max-old-space-size=4096`
  - Node ベース CLI の安定化目的の可能性があり、現時点では “ノイズ断定”しない
- `POWERLEVEL9K_DISABLE_GITSTATUS=true`
  - zsh の gitstatus による重さ/依存回避目的の可能性があり、現時点では “ノイズ断定”しない
