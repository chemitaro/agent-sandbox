# GC-001 未使用ファイル棚卸し（一次調査）

## 方針
- リポジトリ内の参照有無を `rg` で確認。
- 参照が無いものは「用途分析」の上で削除候補として整理。
- `.agent-home` と `.env` は検査対象外。
- `sandbox.config.example` は `.env.example` にリネームして保持（ユーザー指示）。

## 調査結果（削除候補）

### 1) `sandbox.config`（削除済み）
- 参照: なし（`rg -n "sandbox.config"` の結果は `sandbox.config.example` 内コメントのみ）
- 用途分析: ローカル運用設定の旧形式で、現行運用では不要との指示あり。
- 判定: 削除

### 2) `sandbox.config.example` → `.env.example`（リネーム済み）
- 参照: `sandbox.config.example` 自身のコメントのみ
- 用途分析: 例示ファイルとしては必要だが形式は `.env.example` に統一する方針
- 判定: リネームして保持

### 3) `docker-compose.git-ro.yml`（削除済み）
- 参照: なし（`rg -n "docker-compose.git-ro.yml"` でヒットなし）
- 用途分析: Git metadata を read-only にする旧フロー用のオーバーライド。現在は「書き込み可能がデフォルト」とのコメントがあり、利用されていない。
- 判定: 削除候補

### 4) `scripts/generate-git-ro-overrides.sh`（削除済み）
- 参照: なし（自分自身の Usage コメントのみ）
- 用途分析: `docker-compose.git-ro.yml` を生成するための補助スクリプト。現行フローでは未使用。
- 判定: 削除候補

### 5) `scripts/get-tmux-session.sh`（削除済み）
- 参照: `Makefile` で変数 `GET_TMUX_SESSION` が定義されるが、その変数は他で使用されていない
- 用途分析: 旧 Makefile フローの補助スクリプトの可能性
- 判定: 削除候補

### 6) `product/.keep`（削除済み）
- 参照: なし（`product/` は空で `.keep` のみ）
- 用途分析: 空ディレクトリ保持用のプレースホルダ。実運用で使用されていない。
- 判定: 削除候補（削除後は `product/` 自体が空なら削除）

### 7) `scripts/tmux-claude`（削除済み）
- 参照: なし（`rg -n "\\btmux-claude\\b"` でヒットなし）
- 用途分析: tmux + エージェント起動の補助スクリプト（任意機能）。不要方針のため削除。
- 判定: 削除

### 8) `scripts/tmux-codex`（削除済み）
- 参照: なし（`rg -n "\\btmux-codex\\b"` でヒットなし）
- 用途分析: tmux + codex 起動の補助スクリプト（任意機能）。不要方針のため削除。
- 判定: 削除

### 9) `scripts/tmux-opencode`（削除済み）
- 参照: なし（`rg -n "\\btmux-opencode\\b"` でヒットなし）
- 用途分析: tmux + opencode 起動の補助スクリプト（任意機能）。不要方針のため削除。
- 判定: 削除

### 10) `CHANGELOG.md`（削除済み）
- 参照: なし（コード/テスト/スクリプトから参照されていない）
- 用途分析: 上流ツールの changelog であり、本リポジトリの運用（sandbox CLI）に必須ではない
- 判定: 削除

### 11) `CLAUDE.md`（削除済み）
- 参照: 以前は `README.md` からリンクされていたが、README は一旦削除する方針
- 用途分析: ガイドドキュメント。README 作り直し時に必要なら再作成する
- 判定: 削除

### 12) `README.md`（削除済み）
- 参照: なし（実行系は参照しない）
- 用途分析: 後で作り直す前提で、一旦削除
- 判定: 削除

### 13) `.devcontainer/`（削除済み）
- 参照: なし（VS Code が読むのみ）
- 用途分析: Devcontainer サポートは積極メンテしておらず、現行の動的マウント仕様ともズレがあったため削除
- 判定: 削除

## 保持（明確に残す）
- `.env`（ローカル運用データ）
- `.agent-home/`（検査対象外）
- `.env.example`（`sandbox.config.example` の後継として残す）

## 次アクション候補
- 上記削除/リネーム済みのため、参照残存チェックを継続

## 補足: Makefile の整理
- 方針: 公開コマンドは `install` / `help` のみ残す
- 対応: 不要な変数・古いヘルプ記述を削除し、ヘルプ内容を更新
