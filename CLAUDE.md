# Sandbox 環境 使用ガイド（コーディングエージェント向け）

## 概要

このドキュメントは、Claude Codeなどのコーディングエージェントが、Sandbox環境を効果的に使用するためのガイドです。Sandbox環境は、セキュアで隔離されたDocker環境で開発作業を行うためのツールセットです。

## 環境の特徴

- **作業ディレクトリ**: `/srv/product` - すべての開発作業はここで行います
- **ツール配置**: `/opt/sandbox` - Sandbox管理ツール（通常触る必要はありません）
- **利用可能なツール**: Claude Code、Gemini CLI、uv（Python）、Git、Docker、その他開発ツール
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
make start         # コンテナ起動してproductディレクトリに接続
make shell         # productディレクトリに接続（デフォルト）
make shell-sandbox # sandboxディレクトリに接続
make down          # コンテナ停止
make rebuild       # コンテナ再ビルド
make status        # コンテナ状態確認
```

### 開発セッション管理
```bash
make tmux-claude <name>    # tmuxセッションでClaude起動（productディレクトリ）
make tmux-claude-wt <name> # tmuxセッションでClaude起動（特定worktree）
make claude                # 現在のシェルでClaude起動
```

## 作業ワークフロー例

### 1. 新規プロジェクトの開始
```bash
# ホスト側
make tmux-claude new-project

# コンテナ内（自動的に起動）
cd /srv/product
git init my-app
cd my-app
# Claude Codeが起動しているので、そのまま開発開始
```

### 2. 既存プロジェクトの作業
```bash
# ホスト側（SOURCE_PATHに既存プロジェクトを設定済み）
make start

# コンテナ内
cd /srv/product
git status
claude --dangerously-skip-permissions
```

### 3. Python プロジェクトの開始
```bash
# コンテナ内
cd /srv/product/my-python-app
uv init .
uv add fastapi uvicorn
uv run python main.py
```

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
docker run -v /srv/product/myapp:/app myimage

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
sudo chown -R node:node /srv/product
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
```
/srv/product/
├── project-a/     # Node.js プロジェクト
├── project-b/     # Python プロジェクト（uv使用）
└── project-c/     # Go プロジェクト
```

### VS Code統合
1. VS Codeで「Remote-Containers: Attach to Running Container」を選択
2. `agent-sandbox`コンテナを選択
3. `/srv/product`をワークスペースとして開く

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