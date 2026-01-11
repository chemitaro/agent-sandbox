# Sandbox 環境 使用ガイド（コーディングエージェント向け）

## 概要

このドキュメントは、Claude Codeなどのコーディングエージェントが、Sandbox環境を効果的に使用するためのガイドです。Sandbox環境は、セキュアで隔離されたDocker環境で開発作業を行うためのツールセットです。

## 環境の特徴

- **作業ディレクトリ**: `/srv/${PRODUCT_NAME}` - すべての開発作業はここで行います（sandbox.configで設定）
- **ツール配置**: `/opt/sandbox` - Sandbox管理ツール（通常触る必要はありません）
- **利用可能なツール**: Claude Code、Gemini CLI、uv（Python）、Git、Docker、Slack通知、その他開発ツール
- **ネットワーク制限**: GitHub、npm、Anthropic APIなど開発に必要なドメインのみアクセス可能

## クイックスタート

### 1. 初回セットアップ（ホスト側で実行）

```bash
# 設定ファイルの初期化
make init

# sandbox.configを編集して必要な設定を記入
# SOURCE_PATH = /path/to/your/project
# GH_TOKEN = ghp_xxxxxxxxxxxx (オプション)

# 環境の起動と接続
make start
```

### 2. 基本的な使い方

#### シンプルな作業開始
```bash
# productディレクトリに接続
make shell

# tmuxセッションでClaude Codeを起動
make tmux-claude my-session
```

#### 特定のworktreeで作業
```bash
# worktreeディレクトリで作業開始
make tmux-claude-wt feature-branch
```

## 主要なMakeコマンド

### コンテナ管理
```bash
make start         # コンテナ起動して作業ディレクトリに接続
make shell         # 作業ディレクトリに接続（/srv/${PRODUCT_NAME}）
make shell-sandbox # sandboxディレクトリに接続
make down          # コンテナ停止
make rebuild       # コンテナ再ビルド
make status        # コンテナ状態確認
```

### 開発セッション管理
```bash
make tmux-claude <name>    # tmuxセッションでClaude起動（作業ディレクトリ）
make tmux-claude-wt <name> # tmuxセッションでClaude起動（特定worktree）
make claude                # 現在のシェルでClaude起動
```

## 作業ワークフロー例

### 1. 新規プロジェクトの開始
```bash
# ホスト側
make tmux-claude new-project

# コンテナ内（自動的に起動）
cd /srv/${PRODUCT_NAME}  # PRODUCT_NAMEで指定したディレクトリ
git init my-app
cd my-app
# Claude Codeが起動しているので、そのまま開発開始
```

### 2. 既存プロジェクトの作業
```bash
# ホスト側（SOURCE_PATHに既存プロジェクトを設定済み）
make start

# コンテナ内
cd /srv/${PRODUCT_NAME}  # PRODUCT_NAMEで指定したディレクトリ
git status
claude --dangerously-skip-permissions
```

### 3. Python プロジェクトの開始
```bash
# コンテナ内
cd /srv/${PRODUCT_NAME}/my-python-app
uv init .
uv add fastapi uvicorn
uv run python main.py
```

### 3.1 pre-commit（フック導入）

`pre-commit install` は `.git/hooks` に書き込みます。  
このSandboxでは `pre-commit` コマンドは **uvx 経由**で提供しています（Pythonは uv-managed / 3.12）。

```bash
# ホスト側（推奨）: コンテナ内で pre-commit install まで実行し、フックのfallbackもuvxに寄せる
make pre-commit-install

# コンテナ内で直接（同等）
pre-commit install
```

注意:
- フックは **ホスト側の `git commit`** でも実行されます。`make pre-commit-install` はホスト実行時のfallbackを `uvx` に寄せるため、ホスト側にも `uv`（= `uvx`）が必要です。
- もし挙動が不安定なら `PRE_COMMIT_VERSION` を指定してバージョン固定してください（`sandbox.config` → `.env` 経由で渡せます）。

### 4. 複数プロジェクトの並行作業
```bash
# セッション1
make tmux-claude frontend

# セッション2（別ターミナル）
make tmux-claude-wt backend-api

# セッションの切り替え
tmux attach -t frontend
tmux attach -t backend-api
```

## ベストプラクティス

### 1. ファイル編集
- 大きな変更は`MultiEdit`ツールを使用
- 小さな変更は`Edit`ツールを使用
- 新規ファイルは`Write`ツールを使用

### 2. コマンド実行
- 長時間実行コマンドは`tmux`セッション内で実行
- ビルドやテストは`Bash`ツールで実行
- インタラクティブな操作が必要な場合は`make shell`を案内

### 3. Git操作
> 🛡️ コンテナ内ではGitメタデータが読み取り専用にマウントされるため、`git commit`や`git push`などの書き込み系コマンドはPermission deniedになります。コードの閲覧や`git status`/`git diff`など参照系コマンドは引き続き利用できます。コミットやプッシュはホスト環境から行ってください。
```bash
# コミット作成（自動的にCo-Authored-Byが追加される）
git add .
git commit -m "feat: add new feature"

# プルリクエスト作成
gh pr create --title "Add new feature" --body "Description"
```

### 4. Docker-on-Docker（重要）

Docker-on-Dockerは、Sandboxコンテナ内から別のDockerコンテナを起動・管理する機能です。

#### 基本的な仕組み

Sandboxコンテナは、ホストのDockerソケット（`/var/run/docker.sock`）をマウントしているため、コンテナ内からホストのDockerエンジンを操作できます。

#### 重要な制約事項

**ボリュームマウントを行う場合、パスはホスト側の絶対パスを指定する必要があります。**

```bash
# ❌ 間違い：コンテナ内のパスを使用
docker run -v /srv/${PRODUCT_NAME}/myapp:/app myimage

# ✅ 正しい：ホスト側の絶対パスを使用
docker run -v $HOST_PRODUCT_PATH/myapp:/app myimage
```

#### 環境変数の説明

Sandboxコンテナには以下の環境変数が自動設定されています：

- `HOST_SANDBOX_PATH`: ホスト側のSandboxディレクトリの絶対パス
- `HOST_PRODUCT_PATH`: ホスト側のproductディレクトリの絶対パス（SOURCE_PATHと同じ）
- `HOST_USERNAME`: ホスト側のユーザー名

#### 実践例

1. **単純なコンテナ実行**
```bash
# 環境変数不要の場合
docker run --rm hello-world
docker run --rm -it alpine sh
```

2. **ボリュームマウントが必要な場合**
```bash
# 現在のプロジェクトをマウント
docker run --rm -v $HOST_PRODUCT_PATH:/workspace \
  -w /workspace \
  node:20 npm test

# 特定のサブディレクトリをマウント
docker run --rm -v $HOST_PRODUCT_PATH/backend:/app \
  -w /app \
  python:3.11 python main.py
```

3. **docker-compose使用時**
```yaml
# docker-compose.yml の例
version: '3.8'
services:
  app:
    image: myapp
    volumes:
      # 環境変数を使用してホストパスを指定
      - ${HOST_PRODUCT_PATH}/src:/app/src
      - ${HOST_PRODUCT_PATH}/data:/app/data
```

```bash
# 実行時は環境変数が自動的に展開される
docker-compose up -d
```

4. **動的なパス生成**
```bash
# 作業中のプロジェクトパスを取得
CURRENT_PROJECT="$HOST_PRODUCT_PATH/$(basename $PWD)"

# そのパスをDockerで使用
docker run --rm -v $CURRENT_PROJECT:/project \
  -w /project \
  maven:3.8 mvn clean install
```

#### トラブルシューティング

**「cannot find file」エラーが発生する場合**
- コンテナ内のパスではなく、ホスト側のパスを使用しているか確認
- `echo $HOST_PRODUCT_PATH`で環境変数が設定されているか確認

**パーミッションエラーが発生する場合**
```bash
# ユーザーIDを合わせて実行
docker run --rm -u $(id -u):$(id -g) \
  -v $HOST_PRODUCT_PATH:/workspace \
  node:20 npm install
```

### 5. 環境変数の管理

```bash
# sandbox.configに追加
API_KEY = sk-xxxxxxxxxxxx
DATABASE_URL = postgres://localhost/mydb

# 再生成して反映
make generate-env
make restart
```

### 6. Slack通知

ビルドやテストの結果をSlackに通知できます：

```bash
# 基本的な使い方
slack-notify "デプロイが完了しました"

# CI/CDパイプラインでの使用例
npm test && slack-notify "✅ テスト成功" || slack-notify "❌ テスト失敗"

# 詳細情報を含む通知
slack-notify "ビルド完了: バージョン $(git describe --tags) by $(git config user.name)"

# スクリプト内での使用
#!/bin/bash
if make build; then
    slack-notify "ビルド成功: プロジェクト $(basename $PWD)"
else
    slack-notify "@channel ビルド失敗: 確認が必要です"
fi
```

環境変数の設定（sandbox.config）：
```ini
SLACK_WEBHOOK_URL = https://hooks.slack.com/services/YOUR/WEBHOOK/URL
SLACK_CHANNEL = #dev-notifications
SLACK_USERNAME = Sandbox Bot
SLACK_ICON_EMOJI = :rocket:
```

## トラブルシューティング

### コンテナが起動しない
```bash
# 状態確認
make status
docker ps -a

# クリーンアップして再起動
make down
make rebuild
```

### tmuxセッションにアクセスできない
```bash
# セッション一覧確認
tmux list-sessions

# 既存セッションに再接続
make tmux-claude existing-session
```

### ネットワークアクセスエラー
- 許可されたドメインのみアクセス可能
- 新しいドメインが必要な場合は`init-firewall.sh`の更新が必要

### パーミッションエラー
```bash
# ファイル所有者確認
ls -la

# 必要に応じて権限変更
sudo chown -R node:node /srv/${PRODUCT_NAME}
```

## 高度な使い方

### カスタム環境変数
```ini
# sandbox.config
OPENAI_API_KEY = sk-xxxxxxxxxxxx
GEMINI_API_KEY = your-gemini-api-key
CUSTOM_VAR = value
```

### 複数プロジェクトの管理

**PRODUCT_NAME設定による分離**:
sandbox.configで`PRODUCT_NAME`を設定することで、プロジェクトごとに独立した環境を作成できます：

```
# Project A の設定（sandbox.config）
SOURCE_PATH = /Users/yourname/projects/frontend
PRODUCT_NAME = frontend
# → /srv/frontend にマウント

# Project B の設定（別のsandbox.config）  
SOURCE_PATH = /Users/yourname/projects/backend
PRODUCT_NAME = backend
# → /srv/backend にマウント
```

これにより、Claude CodeとCodex CLIの設定がプロジェクトごとに分離されます。

### VS Code Devcontainer統合

devcontainer.jsonは`${localEnv:PRODUCT_WORK_DIR}`を使用してワークスペースフォルダーを動的に設定します。

#### 推奨方法：direnvを使用（自動環境変数読み込み）
```bash
# direnvをインストール（初回のみ）
# macOS: brew install direnv
# Ubuntu: apt install direnv

# プロジェクトディレクトリで.envrcを有効化
direnv allow

# VS Codeを起動（環境変数が自動的に読み込まれる）
code .
```

**注意**: `make init`や`make generate-env`を実行すると、`.envrc`ファイルが自動生成されます。

#### 手動方法：.envを読み込んでからVS Code起動
```bash
# macOS/Linux
set -a; source .env; set +a; code .

# Windows PowerShell
Get-Content .env | ForEach-Object {
  if ($_ -match '^\s*([^#][^=]+)=(.*)') {
    [Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process")
  }
}; code .
```

#### VS Code内での手順
1. VS Codeが起動したら、「Reopen in Container」をクリック
2. または、コマンドパレット（`Ctrl/Cmd+Shift+P`）で「Dev Containers: Reopen in Container」を選択
3. 自動的に`/srv/${PRODUCT_NAME}`がワークスペースとして開きます

#### トラブルシューティング
- **「ワークスペース フォルダーは絶対パスである必要があります」エラー**
  - direnvを使用するか、手動で.envを環境変数として読み込んでからVS Codeを起動してください
- **ワークスペースが/srv/productになる**
  - PRODUCT_WORK_DIR環境変数が設定されていません
  - `direnv allow`を実行するか、手動で.envを読み込んでください

## セキュリティに関する注意

- コンテナは`node`ユーザーで実行（非root）
- ネットワークアクセスは制限済み
- 機密情報は`sandbox.config`に記載（.gitignore済み）
- GitHubトークンなどは環境変数で管理

## まとめ

このSandbox環境は、セキュアで効率的な開発作業を可能にします。主要なコマンドを覚えれば、様々なプロジェクトで快適に作業できます。問題が発生した場合は、このガイドのトラブルシューティングセクションを参照してください。

---
最終更新: 2025-07-02
対象: Claude Code、その他のコーディングエージェント
