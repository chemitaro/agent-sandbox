# Claude Code Container Environment 要件定義

## 1. 概要

このプロジェクトは、Claude Codeを安全に実行するためのコンテナ環境を提供します。
セキュリティを重視し、非root権限でClaude Codeを実行し、ネットワークアクセスを制限した環境を構築します。

## 2. 現在の実装状況

### 2.1 Devcontainer構成

#### ファイル構成
- `.devcontainer/devcontainer.json`: VS Code Devcontainerの設定ファイル
- `Dockerfile`: コンテナイメージの定義（ルートディレクトリ）
- `scripts/init-firewall.sh`: ネットワークセキュリティ設定スクリプト
- `scripts/docker-entrypoint.sh`: コンテナエントリーポイントスクリプト
- `scripts/migrate-config.sh`: 設定ファイル移行スクリプト
- `.env`: 環境変数設定ファイル

#### 主要な機能
1. **非rootユーザー実行**: `node`ユーザー（UID: 1000）でClaude Codeを実行
2. **ネットワーク制限**: iptablesとipsetを使用して、許可されたドメインのみアクセス可能
3. **ボリュームマウント**:
   - `claude-code-bashhistory`: bashの履歴を永続化
   - `claude-code-config`: Claude Codeの設定を永続化
   - `workspace`: 作業ディレクトリのバインドマウント
   - `product`: 外部ディレクトリの読み取り専用マウント
4. **開発ツール**: git, zsh, fzf, delta等の開発ツールを事前インストール
5. **VS Code拡張機能**: ESLint, Prettier, GitLens等を自動インストール

### 2.2 セキュリティ設定

#### ネットワーク制限
許可されたドメイン:
- GitHub関連（API、Web、Git）
- registry.npmjs.org
- api.anthropic.com
- sentry.io
- statsig.anthropic.com
- statsig.com

#### 権限設定
- コンテナは`node`ユーザーで実行
- `init-firewall.sh`のみ`sudo`で実行可能（NOPASSWD設定）
- ネットワーク管理のため`NET_ADMIN`と`NET_RAW`のcapabilityを付与

## 3. 移行要件

### 3.1 Docker Compose対応

#### 必要なファイル
1. `docker-compose.yml`: Docker Composeの設定ファイル
2. 既存の`Dockerfile`を流用
3. 既存の`init-firewall.sh`を流用

#### 要件
1. **互換性の維持**: 現在のDevcontainer環境と同等の機能を提供
2. **設定の一元化**: 環境変数、ボリューム、ネットワーク設定をdocker-compose.ymlに集約
3. **起動方法の簡素化**: `docker-compose up`コマンドで環境を起動
4. **セキュリティの維持**: 現在のセキュリティレベルを維持

### 3.2 VS Code統合

#### Devcontainerのリモート接続
1. Docker Composeで起動したコンテナに、VS CodeのDevcontainer機能で接続可能にする
2. 既存の`devcontainer.json`を修正し、実行中のコンテナへのアタッチをサポート
3. VS Code拡張機能や設定は、接続時に適用される

#### 両立する起動方法
1. **方法1: 従来のDevcontainer**
   - VS Codeから直接Devcontainerを起動
   - 開発環境の自動構築

2. **方法2: Docker Compose + VS Code接続**
   - `docker-compose up`でコンテナを起動
   - VS CodeのRemote Containers拡張機能で既存コンテナに接続
   - CI/CDや自動化環境での利用に適している

## 4. 実装詳細

### 4.1 docker-compose.yml の構成

```yaml
version: '3.8'

services:
  agent-sandbox:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        TZ: ${TZ:-America/Los_Angeles}
    container_name: agent-sandbox
    user: node
    working_dir: /workspace
    environment:
      - NODE_OPTIONS=--max-old-space-size=4096
      - CLAUDE_CONFIG_DIR=/home/node/.claude
      - POWERLEVEL9K_DISABLE_GITSTATUS=true
      - DEVCONTAINER=true
    volumes:
      - .:/workspace:delegated
      - claude-code-bashhistory:/commandhistory
      - claude-code-config:/home/node/.claude
      - ${SOURCE_PATH}:/workspace/product:ro
    cap_add:
      - NET_ADMIN
      - NET_RAW
    env_file:
      - .env
    command: /bin/zsh
    stdin_open: true
    tty: true
    init: true

volumes:
  claude-code-bashhistory:
  claude-code-config:
```

### 4.2 devcontainer.json の修正

既存のdevcontainer.jsonに以下のオプションを追加:
- `dockerComposeFile`: docker-compose.ymlを参照
- `service`: 使用するサービス名を指定
- `shutdownAction`: コンテナの停止動作を設定

### 4.3 起動手順

#### Docker Composeでの起動
```bash
# コンテナの起動
docker-compose up -d

# コンテナへの接続
docker-compose exec agent-sandbox /bin/zsh

# Claude Codeの実行
claude --dangerously-skip-permissions
```

#### VS Codeでの接続
1. Docker Composeでコンテナを起動
2. VS CodeのRemote Containers拡張機能を使用
3. "Attach to Running Container"を選択
4. "agent-sandbox"コンテナを選択

## 5. 移行の利点

1. **柔軟性の向上**: Docker ComposeとDevcontainerの両方の利点を活用
2. **CI/CD対応**: docker-composeコマンドによる自動化が容易
3. **環境の再現性**: docker-compose.ymlによる設定の明確化
4. **既存資産の活用**: 現在のDockerfileとスクリプトをそのまま使用
5. **段階的移行**: 両方の起動方法をサポートすることで、段階的な移行が可能

## 6. Docker-on-Docker機能

### 6.1 概要

コンテナ内からDockerコマンドを実行できる機能を追加。ホストのDockerデーモンを利用することで、イメージサイズの肥大化を防ぎつつ、開発の柔軟性を向上。

### 6.2 実装詳細

#### Docker CLIのインストール
- Docker Engine不要、CLIとdocker-compose-pluginのみ
- dockerグループ（GID: 999）の作成
- nodeユーザーのdockerグループへの追加

#### Dockerソケットのマウント
```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
  - ${HOST_WORKSPACE_ROOT:-./}:/workspace/host:ro
```

#### エントリポイントスクリプト
- `scripts/docker-entrypoint.sh`でDockerソケットの権限を動的に調整
- ホストとコンテナのGIDの違いを自動処理
- gosuを使用した安全な権限切り替え

### 6.3 使用例

```bash
# コンテナ内からDockerイメージのビルド
docker build -t myapp .

# docker-composeの実行
docker-compose up -d

# ホストのコンテナ一覧を確認
docker ps
```

### 6.4 セキュリティ考慮事項

1. **最小権限の原則**: DockerコマンドのみをSUDO許可
2. **読み取り専用マウント**: ホストのワークスペースは読み取り専用でマウント
3. **監査**: Docker操作はすべてログに記録される

## 7. 注意事項

1. **セキュリティ**: init-firewall.shの実行タイミングに注意
2. **環境変数**: .envファイルの管理（特にGH_TOKENなどの機密情報）
3. **ボリューム**: 永続化が必要なデータの適切な管理
4. **互換性**: VS Codeのバージョンとの互換性確認
5. **Docker-on-Docker**: Dockerソケットへのアクセスは慎重に管理