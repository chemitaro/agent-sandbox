# Sandboxプロジェクト要件定義書

## 実装計画とタスク管理

本プロジェクトの実装計画は @TODO.md で管理されています。

### TODO.mdの利用方法

1. **進捗確認**: TODO.mdを開いて現在の進捗状況を確認
2. **タスク開始**: 作業を開始する際は `[ ]` を `[~]` に変更
3. **タスク完了**: 作業が完了したら `[x]` に変更
4. **問題発生時**: 該当タスクの下にサブタスクを追加して詳細を記録

### チェックボックスの状態
- `[ ]` : 未着手
- `[~]` : 作業中
- `[x]` : 完了

実装作業を行う際は、必ずTODO.mdを参照し、計画に沿って進めてください。

## 1. プロジェクト概要

### 1.1 背景
Claude Code（Anthropic公式のコーディング支援ツール）は強力な開発支援機能を提供するが、セキュリティ面での懸念から隔離された環境での実行が望ましい。本プロジェクトは、安全かつ効率的な開発環境を提供することを目的とする。

### 1.2 プロジェクト名称
- 現在: `box`
- 変更後: `sandbox` （より具体的で開発者に馴染みのある名称）

### 1.3 主要機能
1. **セキュアな実行環境**: iptablesとipsetによるネットワークアクセス制御
2. **Docker-on-Docker (DonD)**: コンテナ内からのDocker操作を可能に
3. **データ永続化**: 設定とコマンド履歴の保持
4. **開発ツール統合**: VS Code Devcontainerとの連携

## 2. 現状の課題

### 2.1 ディレクトリ構造の問題
- すべてのファイルが`/workspace`配下に混在
- 支援ツールと開発対象プロダクトの境界が不明確
- 標準的なLinuxディレクトリ規約から逸脱

### 2.2 環境依存の問題
- ユーザー名やパスがハードコード（例: `/Users/iwasawayuuta/`）
- 他の開発者が利用する際の移植性が低い
- Docker-on-Dockerのパス変換が特定環境に依存

### 2.3 設定管理の問題
- `.env`ファイルの直接編集はエラーを誘発しやすい
- 必須項目と自動取得可能な項目が混在
- 設定の検証機能が不足

## 3. 解決策

### 3.1 ディレクトリ構造の再設計

#### 新しいマウント構造
```
/opt/sandbox/    # Sandboxツール本体（支援ツール）
├── .devcontainer/
├── docker-compose.yml
├── Makefile
└── その他の設定ファイル

/srv/product/    # 開発対象プロダクト（メイン作業場所）
└── ユーザーのソースコード
```

#### 設計理念
- `/opt/`: オプショナルなソフトウェアパッケージ用（FHS準拠）
- `/srv/`: サイト固有のデータ用（FHS準拠）
- ワーキングディレクトリを`/srv/product`に設定し、開発作業の焦点を明確化

### 3.2 環境変数の動的管理システム

#### 3段階の設定フロー
```
sandbox.config（ユーザー編集） → Makefile（処理） → .env（自動生成）
```

#### sandbox.configの仕様
```ini
# Sandbox Configuration File
# 必須設定のみをシンプルに記述

# 必須: GitHubトークン
GH_TOKEN = ghp_xxxxxxxxxxxxxxxxxxxx

# 必須: 開発対象プロダクトのパス
SOURCE_PATH = /path/to/your/project

# オプション: タイムゾーン（デフォルト: 自動検出）
# 指定しない場合はローカルシステムから自動的に取得されます
# TZ = Asia/Tokyo

# カスタム環境変数（任意）
# 任意の環境変数を KEY = VALUE 形式で追加可能
API_KEY = your-api-key
DATABASE_URL = postgres://localhost/mydb
NODE_ENV = development
```

**特徴:**
- すべての `KEY = VALUE` 形式の行が自動的に.envファイルに含まれる
- コメント行（#で始まる行）は無視される
- 環境変数名は大文字とアンダースコアを使用

#### 自動取得される環境変数
- `HOST_SANDBOX_PATH`: Gitリポジトリのルート（`git rev-parse --show-toplevel`）
- `HOST_USERNAME`: 実行ユーザー名（`whoami`）
- `HOST_PRODUCT_PATH`: `source_path`と同じ値（Docker-on-Docker用）
- `TZ`: ローカルシステムのタイムゾーン（自動検出）

### 3.3 プロジェクト名の統一
すべての箇所で`box`を`sandbox`に変更：
- ディレクトリ名
- コンテナ名: `claude-code-sandbox`
- 設定ファイル名: `sandbox.config`
- ドキュメント内の記述

## 4. 技術仕様

### 4.1 Makefileの拡張機能

#### 新規コマンド
```bash
make init            # sandbox.configの初期作成
make generate-env    # .envファイルの自動生成
make validate-config # 設定の検証
make show-config     # 現在の設定表示
make shell-product   # /srv/productで直接作業開始
make clean-env       # 生成された.envを削除
```

#### タイムゾーン自動検出の実装例
```makefile
# タイムゾーンの自動検出
detect-timezone:
	@if [ -n "$$TZ" ]; then \
		echo "$$TZ"; \
	elif [ -L /etc/localtime ]; then \
		readlink /etc/localtime | sed 's|.*/zoneinfo/||'; \
	elif [ -f /etc/timezone ]; then \
		cat /etc/timezone; \
	elif command -v timedatectl >/dev/null 2>&1; then \
		timedatectl | grep "Time zone" | awk '{print $$3}'; \
	else \
		echo "Asia/Tokyo"; \
	fi

DETECTED_TZ := $(shell $(MAKE) -s detect-timezone)
```

#### .env自動生成ロジック
1. `sandbox.config`の存在確認
2. 必須項目の検証
   - source_path（必須）: 開発対象のパス
   - github_token（オプション）: プライベートリポジトリアクセス時のみ必要
3. 動的値の取得
   - HOST_SANDBOX_PATH: `git rev-parse --show-toplevel`
   - HOST_USERNAME: `whoami`
   - TZ: タイムゾーンの自動検出（以下の優先順位で取得）
     - macOS: `readlink /etc/localtime | sed 's|.*/zoneinfo/||'`
     - Linux: `/etc/timezone`の内容または`timedatectl`コマンド
     - 環境変数: `$TZ`
     - フォールバック: `Asia/Tokyo`
4. `.env`ファイルの生成（タイムスタンプ付き）
5. ソースパスの存在確認（警告のみ）

### 4.2 Docker-on-Docker改善

#### 環境変数を使用したパスマッピング
```yaml
# compose.ymlでのボリューム設定
volumes:
  - ${CURRENT_PROJECT_PATH:-./}:/srv/current_project:cached
```

```bash
# .envファイルでのパス設定
CURRENT_PROJECT_PATH=/Users/iwasawayuuta/workspace/product/taikyohiyou_project
```

Docker-on-Docker環境では、コンテナ内の相対パスをホストの絶対パスに変換する必要があります。
この問題は環境変数を使用することで解決できます。

### 4.3 ファイル別の修正内容

#### 高優先度（コア機能）
1. **CLAUDE.md**: 要件定義（本ドキュメント）
2. **sandbox.config.example**: ユーザー設定テンプレート
3. **Makefile**: 自動化機能の実装
4. **docker-compose.yml**: マウントパスとコンテナ名の変更

#### 中優先度（連携機能）
5. **Dockerfile**: ディレクトリ作成（/opt/sandbox, /srv/product）
6. **docker-entrypoint.sh**: Dockerソケットの権限設定
7. **devcontainer.json**: VS Code統合の更新

#### 低優先度（補助機能）
8. **.gitignore**: sandbox.configの追加
9. **.env.example**: 廃止予定の通知
10. **README.md/USAGE.md**: 新しい使用方法の文書化

## 5. 実装計画

### Phase 1: 基盤構築（必須）
1. CLAUDE.md作成（要件定義）✓
2. sandbox.config.exampleの作成
3. Makefileの自動化機能実装
4. 基本的な動作確認

### Phase 2: コア機能実装
5. docker-compose.ymlの更新
6. Dockerfileの更新
7. 統合テスト

### Phase 3: 周辺機能更新
8. Docker-on-Dockerパスマッピングの改善
9. devcontainer.jsonの更新
10. VS Code統合テスト

### Phase 4: 仕上げ
11. 全ファイルでの名称変更（box→sandbox）
12. ドキュメント更新
13. 最終動作確認

## 6. 期待される成果

### 6.1 開発者体験の向上
- **簡単なセットアップ**: `make init`から始まる直感的なフロー
- **エラーの削減**: 自動化による設定ミスの防止
- **環境非依存**: どのマシンでも同じ手順で動作
- **ローカル環境との同期**: タイムゾーンが自動的にホストと同期

### 6.2 保守性の向上
- **明確な責務分離**: ツールと作業対象の境界が明確
- **拡張性**: 新機能追加が容易な構造
- **標準準拠**: FHSに従ったディレクトリ構造

### 6.3 セキュリティの維持
- 既存のネットワーク制御機能は維持
- 非rootユーザーでの実行を継続
- 機密情報（.env, sandbox.config）のGit管理除外

## 7. リスクと対策

### 7.1 既存環境への影響
- **リスク**: 既存ユーザーのコンテナが動作しなくなる
- **対策**: 移行ガイドの作成、段階的な移行サポート

### 7.2 パス変更による不具合
- **リスク**: ハードコードされたパスによる機能不全
- **対策**: 徹底的な検索と置換、統合テストの実施

### 7.3 設定ミスによる起動失敗
- **リスク**: sandbox.configの記述ミス
- **対策**: validate-configコマンドでの事前検証、分かりやすいエラーメッセージ

## 8. 将来の拡張性

### 8.1 複数プロダクト対応
```bash
make up PROJECT=project1      # 異なるプロダクトでの起動
make switch PROJECT=project2  # プロダクトの切り替え
```

### 8.2 プロファイル機能
```ini
[development]
source_path = /path/to/dev

[production]
source_path = /path/to/prod
```

### 8.3 プラグインシステム
- カスタムツールの追加
- 言語別の開発環境プリセット
- CI/CD統合の強化

## 9. 成功指標

1. **機能性**: すべての既存機能が新構造で動作すること
2. **使いやすさ**: セットアップ時間が5分以内
3. **移植性**: 3種類以上の異なる環境での動作確認
4. **保守性**: 新機能追加が既存の30%以下の工数で可能

## 10. まとめ

本要件定義は、Sandboxプロジェクトをより使いやすく、保守しやすく、拡張しやすいツールへと進化させるための指針です。段階的な実装により、既存ユーザーへの影響を最小限に抑えながら、大幅な改善を実現します。

---
作成日: 2025-07-01
作成者: Claude Code Assistant
バージョン: 1.1

## 更新履歴
- v1.1 (2025-07-01): タイムゾーン自動検出機能の追加
- v1.0 (2025-07-01): 初版作成