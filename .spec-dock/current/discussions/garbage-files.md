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

## 保持（明確に残す）
- `.env`（ローカル運用データ）
- `.agent-home/`（検査対象外）
- `.env.example`（`sandbox.config.example` の後継として残す）

## 次アクション候補
- 上記削除/リネーム済みのため、参照残存チェックを継続

## 補足: Makefile の整理
- 方針: 公開コマンドは `install` / `help` のみ残す
- 対応: 不要な変数・古いヘルプ記述を削除し、ヘルプ内容を更新
