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
docker-compose exec agent-sandbox /bin/zsh
```

### 3. ファイアウォールの設定（推奨）

セキュリティを強化するため、コンテナ内でファイアウォールを設定します：

```bash
# rootユーザーとして実行
docker-compose exec -u root agent-sandbox /usr/local/bin/init-firewall.sh
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

## 方法2: VS Code Devcontainer を使用した起動（新方式）

### 新しいDevcontainer設定について

2025年7月より、devcontainerの構成が軽量化されました。新しい設定では：
- Devcontainerは独自のコンテナをビルドせず、Docker Composeで起動したコンテナにアタッチします
- 環境構築はすべてDocker Compose側で行われます
- VS Code固有の設定（拡張機能、エディタ設定）のみがdevcontainer.jsonに記載されます

### 新方式での使用手順

1. **必須**: まずDocker Composeでコンテナを起動
   ```bash
   make up
   ```

2. VS Code でプロジェクトフォルダを開く
   ```bash
   code .
   ```

3. 以下のいずれかの方法でコンテナに接続：
   - ポップアップで「Reopen in Container」をクリック
   - コマンドパレット（Cmd/Ctrl + Shift + P）で `Dev Containers: Reopen in Container` を選択

4. VS Codeが既存のコンテナにアタッチし、`/srv/product`が作業ディレクトリとして開かれます

5. ターミナルで Claude Code を実行：
   ```bash
   claude --dangerously-skip-permissions
   ```

### 新方式の利点

- **高速な起動**: ビルド済みコンテナにアタッチするため、即座に開発を開始可能
- **一貫性**: CLIとVS Codeで完全に同じ環境を使用
- **柔軟性**: コンテナを停止せずにVS Codeの接続/切断が可能
- **設定の明確化**: 環境設定とエディタ設定が明確に分離

### 従来の方式からの移行

既存のdevcontainerユーザーの方は、以下の手順で移行してください：

1. VS Codeで開いているdevcontainerを閉じる
2. `make down`で既存のコンテナを停止
3. 最新のリポジトリをpull
4. 上記の「新方式での使用手順」に従って再度開く

### トラブルシューティング

**Q: "Reopen in Container"を選択してもエラーが出る**
A: Docker Composeコンテナが起動していることを確認してください：
```bash
make status
# コンテナが起動していない場合
make up
```

**Q: 作業ディレクトリが `/srv/product` ではない**
A: devcontainer.jsonが最新版であることを確認してください。古いキャッシュが残っている場合は、VS Codeを再起動してください。

## 方法3: Docker Compose + VS Code の組み合わせ（従来方式）

### Docker Composeで起動したコンテナにVS Codeで接続

1. まず、Docker Composeでコンテナを起動：
   ```bash
   make up
   ```

2. VS Code を開く

3. コマンドパレット（Cmd/Ctrl + Shift + P）を開く

4. `Dev Containers: Attach to Running Container...` を選択

5. `agent-sandbox` コンテナを選択

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
docker-compose logs agent-sandbox

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
docker volume ls | grep agent-sandbox
```