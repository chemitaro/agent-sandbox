# Claude Code Container 使用方法

このドキュメントでは、Claude Codeを安全なコンテナ環境で実行する2つの方法を説明します。

## 前提条件

- Docker Desktop がインストールされていること
- VS Code がインストールされていること（VS Code連携を使用する場合）
- VS Code Remote - Containers 拡張機能がインストールされていること（VS Code連携を使用する場合）

## 方法1: Docker Compose を使用した起動

### 1. 環境の起動

```bash
# コンテナを起動
make up

# または直接docker-composeコマンドを使用
docker-compose up -d
```

### 2. コンテナへの接続

```bash
# コンテナのシェルに接続
make shell

# または直接docker-composeコマンドを使用
docker-compose exec claude-code /bin/zsh
```

### 3. ファイアウォールの設定（推奨）

セキュリティを強化するため、コンテナ内でファイアウォールを設定します：

```bash
# rootユーザーとして実行
docker-compose exec -u root claude-code /usr/local/bin/init-firewall.sh
```

**注意**: この設定により、許可されたドメイン以外へのアクセスが制限されます。

### 4. Claude Codeの実行

コンテナ内で以下のコマンドを実行：

```bash
claude --dangerously-skip-permissions
```

### 5. その他の便利なコマンド

```bash
# ログの表示
make logs

# コンテナの状態確認
make status

# コンテナの再起動
make restart

# コンテナの停止・削除
make down
```

## 方法2: VS Code Devcontainer を使用した起動

### 従来のDevcontainer機能を使用

1. VS Code でプロジェクトフォルダを開く
2. コマンドパレット（Cmd/Ctrl + Shift + P）を開く
3. `Dev Containers: Reopen in Container` を選択
4. コンテナが自動的にビルド・起動される
5. VS Code のターミナルで `claude --dangerously-skip-permissions` を実行

## 方法3: Docker Compose + VS Code の組み合わせ

### Docker Composeで起動したコンテナにVS Codeで接続

1. まず、Docker Composeでコンテナを起動：
   ```bash
   make up
   ```

2. VS Code を開く

3. コマンドパレット（Cmd/Ctrl + Shift + P）を開く

4. `Dev Containers: Attach to Running Container...` を選択

5. `claude-code-sandbox` コンテナを選択

6. VS Code が新しいウィンドウで開き、コンテナに接続される

7. ターミナルで以下を実行：
   ```bash
   claude --dangerously-skip-permissions
   ```

## 環境変数の設定

`.env` ファイルで以下の環境変数を設定できます：

```bash
# GitHubトークン（必要に応じて）
GH_TOKEN="your_github_token"

# ホストのソースパス（読み取り専用でマウントされる）
SOURCE_PATH="/path/to/your/source"

# タイムゾーン（オプション）
TZ="Asia/Tokyo"
```

## セキュリティ機能

このコンテナ環境には以下のセキュリティ機能が実装されています：

1. **非rootユーザー実行**: nodeユーザー（UID: 1000）で実行
2. **ネットワーク制限**: 許可されたドメインのみアクセス可能
   - GitHub API
   - npm registry
   - Anthropic API
   - その他の必要なサービス
3. **読み取り専用マウント**: `SOURCE_PATH` は読み取り専用でマウント

## トラブルシューティング

### コンテナが起動しない場合

```bash
# ログを確認
docker-compose logs claude-code

# コンテナを再ビルド
docker-compose build --no-cache
docker-compose up -d
```

### ネットワークエラーが発生する場合

ファイアウォールの設定を確認：
```bash
# コンテナ内で実行
sudo /usr/local/bin/init-firewall.sh
```

### VS Codeで接続できない場合

1. Docker Desktop が起動していることを確認
2. コンテナが実行中であることを確認：`make status`
3. VS Code Remote - Containers 拡張機能が最新版であることを確認

## Docker-on-Docker機能

この環境では、コンテナ内からDockerコマンドを使用できます。

### 基本的な使い方

```bash
# Dockerのバージョン確認
docker version

# イメージの一覧
docker images

# コンテナの一覧（ホストのコンテナが表示されます）
docker ps

# イメージのビルド
docker build -t myapp .

# docker-composeの使用（通常）
docker compose up -d
docker compose run --build --rm myapp
```

### 注意事項

1. **ホストのDockerデーモンを使用**: コンテナ内で実行したDockerコマンドは、ホストのDockerデーモンで実行されます
2. **権限**: Dockerコマンドは自動的に適切な権限で実行されます
3. **パスの違い**: コンテナ内のパスとホストのパスが異なることに注意してください
   - コンテナ内: `/workspace`
   - ホスト参照用: `/workspace/host`（読み取り専用）

### トラブルシューティング

Dockerコマンドが使えない場合：
```bash
# Docker権限の確認
groups | grep docker

# Dockerソケットの確認
ls -la /var/run/docker.sock
```

## データの永続化

以下のデータは名前付きボリュームで永続化されます：

- **bashhistory**: コマンド履歴
- **claude-config**: Claude Codeの設定

ボリュームの確認：
```bash
docker volume ls | grep claude-code
```