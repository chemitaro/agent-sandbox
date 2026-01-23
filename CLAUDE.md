# Sandbox 環境 使用ガイド（コーディングエージェント向け）

## 概要

このドキュメントは、Claude Code などのコーディングエージェントが Sandbox 環境を効率よく使うためのガイドです。Sandbox は **任意ディレクトリをマウントして起動できる** Docker 環境です。

## 環境の特徴

- **作業ディレクトリ（コンテナ内）**: `/srv/mount/...`
  - `mount-root` を `/srv/mount` に固定し、`workdir` へは `docker compose exec -w` で入ります
- **ツール配置**: `/opt/sandbox`
- **利用可能なツール**: Claude Code、Gemini CLI、uv（Python）、Git、Docker など
- **ネットワーク制限**: GitHub、npm、Anthropic API など開発に必要なドメインのみ

## クイックスタート（ホスト側）

```bash
# 起動 & シェル接続（デフォルト）
sandbox

# 明示的な操作
sandbox up
sandbox build
sandbox stop
sandbox down
sandbox status
sandbox name
```

### マウントのルール

- **引数なし**
  - Git 管理下: worktree の LCA を `mount-root` として自動推定、`workdir` は現在ディレクトリ
  - Git 管理外: `mount-root = workdir = 現在ディレクトリ`
- **明示指定**
```bash
sandbox shell --mount-root /path/to/repo --workdir /path/to/repo/worktrees/feature-a
```

## 代表的な使い方

### 1. Git worktree で作業
```bash
cd /path/to/repo/worktrees/feature-a
sandbox
# コンテナ内: /srv/mount/worktrees/feature-a
```

### 2. Git 管理外のディレクトリで作業
```bash
cd /path/to/some/project
sandbox
# mount-root = workdir = /path/to/some/project
# コンテナ内: /srv/mount
```

### 3. 共有 secrets（.env）

`agent-sandbox` ルートの `.env` に秘密情報を置きます。**ツールは .env を上書きしません**。

```env
# .env (git-ignored)
GH_TOKEN=ghp_xxxxxxxxxxxx
GEMINI_API_KEY=...
```

## 重要な環境変数（DoD）

コンテナに注入される代表的な環境変数:

- `SOURCE_PATH` = ホストの `abs_mount_root`
- `PRODUCT_WORK_DIR` = `/srv/mount`
- `HOST_SANDBOX_PATH` = sandbox リポジトリの絶対パス
- `HOST_USERNAME` = ホストユーザー名
- `CONTAINER_NAME` / `COMPOSE_PROJECT_NAME` = 同一インスタンスを特定する名前

## Docker-on-Docker（DoD）

Docker ソケットをマウントしているため、コンテナ内から Docker CLI が使えます。
`HOST_PRODUCT_PATH` と `PRODUCT_WORK_DIR=/srv/mount` により、
「コンテナ内パス → ホストパス変換」が成り立つ前提です。

## Git アクセス

- `.git` メタデータは読み取り専用マウント
- `git status`/`git diff` は OK
- `git commit`/`merge`/`push` は **ホスト側** で実行してください

## 注意事項

- `help` / `name` / `status` は副作用なし（`.env` や `.agent-home` を作らない）
- `shell/up/build/stop/down` は必要に応じて `.env`（空ファイル）や `.agent-home` を作成します
- Devcontainer は動的マウント用に積極メンテしていません（必要なら実験的に利用）
