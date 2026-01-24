---
種別: 要件定義書
機能ID: "CHORE-ENV-001"
機能名: "Docker/Compose の不要な環境変数整理"
関連Issue: ["N/A"]
状態: "draft"
作成者: "Codex CLI"
最終更新: "2026-01-23"
---

# CHORE-ENV-001 Docker/Compose の不要な環境変数整理 — 要件定義（WHAT / WHY）

## 目的（ユーザーに見える成果 / To-Be） (必須)
- Dockerfile / docker-compose.yml にある「実質効いていない（またはデフォルトと同一で冗長な）」環境変数を削除し、設定の理解コストと誤解の余地を減らす。
- 設定ファイルの永続化（`.agent-home/` の bind mount）と既存の CLI 動作は維持する。

## 背景・現状（As-Is / 調査メモ） (必須)
- 現状の挙動（事実）:
  - `docker-compose.yml` と `Dockerfile` に、Codex/Claude/Gemini/OpenCode の「設定ディレクトリパス」系の環境変数が定義されている。
  - 一方で、同じパスは `docker-compose.yml` の `volumes:` により `.agent-home/` から既に永続化されている（= env var がなくても“設定はその場所に存在する”）。
- 現状の課題（困っていること）:
  - 読み手が「この env var が必須なのか」「どのツールが参照しているのか」「正しい変数名なのか」を判断できず、設定がノイズ化している。
- 再現手順（最小で）:
  1) `docker-compose.yml` の `environment:` を確認する
  2) `Dockerfile` の `ENV ..._CONFIG_DIR` / `ENV OPENCODE_*_DIR` を確認する
- 観測点（どこを見て確認するか）:
  - Log: ...
  - `docker-compose.yml` / `Dockerfile` の差分（不要な env var が消えていること）
  - `tests/sandbox_cli.test.sh` の成功（既存 CLI の入口が壊れていないこと）
- 実際の観測結果（貼れる範囲で）:
  - `docker-compose.yml` に `CLAUDE_CONFIG_DIR`, `CODEX_CONFIG_DIR`, `GEMINI_CONFIG_DIR`, `OPENCODE_CONFIG_DIR`, `OPENCODE_DATA_DIR`, `OPENCODE_CACHE_DIR` が定義されている。
  - `Dockerfile` に `CODEX_CONFIG_DIR`, `GEMINI_CONFIG_DIR`, `OPENCODE_CONFIG_DIR`, `OPENCODE_DATA_DIR`, `OPENCODE_CACHE_DIR` が定義されている。
- 情報源（ヒアリング/調査の根拠）:
  - ドキュメント:
    - Codex（OpenAI）: `CODEX_HOME` が状態保存先（デフォルト `~/.codex`）
    - Claude Code（Anthropic）: `CLAUDE_CONFIG_DIR` により設定ディレクトリを上書き可能（デフォルト `~/.claude`）
    - Gemini CLI（Google）: ユーザー設定は `~/.gemini/settings.json`（`GEMINI_CONFIG_DIR` はドキュメントに存在しない）
    - OpenCode: 設定は `~/.config/opencode/opencode.json`（`OPENCODE_CONFIG_DIR` は“追加のカスタムディレクトリ”用途、`OPENCODE_DATA_DIR`/`OPENCODE_CACHE_DIR` はドキュメントに存在しない）
  - コード:
    - `docker-compose.yml`（`environment:` と `volumes:` の整合を確認するため）
    - `Dockerfile`（環境変数/ディレクトリ作成の確認のため）
    - `host/sandbox`（Compose に注入している変数の確認のため）
    - `tests/sandbox_cli.test.sh`（動作保証・退行防止の確認のため）

## 対象ユーザー / 利用シナリオ (任意)
- 主な利用者（ロール）:
  - このリポジトリの `sandbox` CLI を使ってコンテナを起動し、CLI（Codex/Claude/Gemini/OpenCode 等）を実行する開発者
- 代表的なシナリオ:
  - `sandbox up` → `sandbox shell` で入り、各 CLI の設定やキャッシュをプロジェクト横断で永続化したい

## スコープ（暴走防止のガードレール） (必須)
- MUST（必ずやる）:
  - Dockerfile / docker-compose.yml から「設定パス系のノイズ環境変数」を削除する（対象は `design.md` で具体化する）
  - `.agent-home/` の bind mount（永続化）は維持する
  - 退行防止として、対象 env var が再導入されないテスト（ファイル検査）を追加/更新する
- MUST NOT（絶対にやらない／追加しない）:
  - マウント先パス（例: `/home/node/.codex`, `/home/node/.claude`, `/home/node/.gemini`, `/home/node/.config/opencode`）の変更
  - CLI の追加機能や仕様変更（env var 整理以外の挙動変更）
  - 認証用の `.env` 変数（APIキー等）の削除
- OUT OF SCOPE（今回やらない）:
  - 各 CLI のインストール方法/バージョン固定方針の変更（npm global の運用変更）
  - `.agent-home/` のディレクトリ構成そのものの変更（必要になったら別タスクで）

## 非交渉制約（守るべき制約） (必須)
- 既存の `sandbox` CLI コマンドとテストが壊れないこと
- “設定の永続化は bind mount が正”という前提（env var によるパス指定に依存しない）を維持すること
- 破壊的 Git 操作をしない（運用ルール上、`git add/commit/push/merge` は禁止）

## 前提（Assumptions） (必須)
- 各 CLI は公式のデフォルト場所（例: `~/.codex`, `~/.claude`, `~/.gemini`, `~/.config/opencode`）を参照できる（= その場所に bind mount がある）。
- 既存の env var は「デフォルトと同一のパスを指している」または「ツール側が参照しない」ため、削除しても実動作に影響しない（影響が出る場合は EC として扱い、設計で保護する）。

## 判断材料/トレードオフ（Decision / Trade-offs） (任意)
- 論点: ...
  - 選択肢A: ...（Pros/Cons）
  - 選択肢B: ...（Pros/Cons）
  - 決定: ...
  - 理由: ...

## リスク/懸念（Risks） (任意)
- R-001: 一部利用者が（非公式な）env var に依存していた場合に挙動が変わる（影響: 低〜中 / 対応: 設計で「公式の正しい変数名」へ誘導し、必要なら `env_file`/README へ移行ガイドを追記）
- R-002: “削除対象”の範囲を広げすぎると意図しない挙動差分が混入する（影響: 中 / 対応: 対象を `design.md` で明確化し、テストで固定）

## 受け入れ条件（観測可能な振る舞い） (必須)
- AC-001:
  - Actor/Role: 開発者
  - Given: リポジトリの `docker-compose.yml` / `Dockerfile` が最新版である
  - When: `docker-compose.yml` / `Dockerfile` を確認する
  - Then: `design.md` で定義した「ノイズ環境変数」が定義されていない（= 余計なパス指定がない）
  - 観測点（UI/HTTP/DB/Log など）: 変更差分（ファイル内容）
- AC-002:
  - Actor/Role: 開発者
  - Given: `sandbox` CLI のテスト環境（stubs）を用意できる
  - When: `bash tests/sandbox_cli.test.sh` を実行する
  - Then: すべて成功する（= 入口 CLI の退行がない）
  - 観測点（UI/HTTP/DB/Log など）: テスト結果（exit code / ログ）

### 入力→出力例 (任意)
- EX-001:
  - Input: Dockerfile / docker-compose の差分
  - Output: “冗長/誤り env var が無い”状態
- EX-002:
  - Input: `bash tests/sandbox_cli.test.sh`
  - Output: exit code 0

## 例外・エッジケース（仕様として固定） (必須)
- EC-001:
  - 条件: “非公式/誤った env var” に依存していた利用者がいる
  - 期待: 公式の正しい代替（例: Codex は `CODEX_HOME`、Claude は `CLAUDE_CONFIG_DIR`）を `design.md` と変更差分に明記し、移行方法が分かる
  - 観測点（UI/HTTP/DB/Log など）: ドキュメント / 差分
- EC-002:
  - 条件: OpenCode の設定ディレクトリをカスタムしている（`OPENCODE_CONFIG_DIR` を意図的に使っている）
  - 期待: デフォルト運用では env var を削除するが、カスタムが必要なら `.env` 等で “ユーザーが明示的に指定する”運用へ切り替えできる
  - 観測点: `design.md` の方針

## 用語（ドメイン語彙） (必須)
- TERM-001: ノイズ環境変数 = 現状の動作に寄与しない（またはデフォルトと同一で冗長な）ため、理解コストだけ増やす環境変数
- TERM-002: 設定の永続化 = `.agent-home/` を bind mount して CLI の設定/キャッシュをホスト側に残すこと

## 未確定事項（TBD / 要確認） (必須)
- Q-001:
  - 質問: `docker-compose.yml` の `environment:` にある `HOST_*` / `PRODUCT_*` は「コンテナ内では未使用」だが、削除して良いか？
  - 決定: A（削除する）
  - 理由: コンテナ内で参照箇所が無く、露出/誤解のノイズになるため
  - 影響範囲: AC-001 / `design.md` / `docker-compose.yml`
- Q-002:
  - 質問: `DOCKER_CONFIG` / `DOCKER_HOST` / `DEVCONTAINER` / `TMUX_SESSION_NAME` のような「重複/目的不明」 env var も同じタスクで削除するか？
  - 決定: A（Dockerfile 側は今回は対象外）
  - 補足: `docker-compose.yml` 側の重複定義（`DEVCONTAINER` / `DOCKER_HOST`）はノイズとして削除した
  - 影響範囲: AC-001 / `design.md` / `Dockerfile` / `docker-compose.yml`

## 完了条件（Definition of Done） (必須)
- すべてのAC/ECが満たされる
- 未確定事項が解消される（残す場合は「残す理由」と「合意」を明記）
- MUST NOT / OUT OF SCOPE を破っていない（追加機能を入れていない）

## 省略/例外メモ (必須)
- 該当なし
