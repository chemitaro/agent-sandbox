---
種別: 設計書
機能ID: "CHORE-ENV-001"
機能名: "Docker/Compose の不要な環境変数整理"
関連Issue: ["N/A"]
状態: "draft"
作成者: "Codex CLI"
最終更新: "2026-01-23"
依存: ["requirement.md"]
---

# CHORE-ENV-001 Docker/Compose の不要な環境変数整理 — 設計（HOW）

## 目的・制約（要件から転記・圧縮） (必須)
- 目的: 「設定ディレクトリのパスを env var で固定する」ノイズを削除し、永続化は bind mount + 公式デフォルトに統一する。
- MUST:
  - `docker-compose.yml` / `Dockerfile` から、削除対象 env var を取り除く（下記参照）。
  - `.agent-home/` の bind mount（永続化）は維持する。
  - 退行防止として、削除対象 env var が再導入されないテストを追加/更新する。
- MUST NOT:
  - マウント先パス（例: `/home/node/.claude`, `/home/node/.codex`, `/home/node/.gemini`, `/home/node/.config/opencode`）の変更
  - 認証用の `.env` 変数（APIキー等）の削除
- 非交渉制約:
  - `sandbox` CLI と既存テストの互換性維持
- 前提:
  - 対象 CLI はデフォルト設定ディレクトリを参照できる（= そのパスに bind mount がある）。

---

## 既存実装/規約の調査結果（As-Is / 95%理解） (必須)
- 参照した規約/実装（根拠）:
  - `AGENTS.md`: 会話/禁止Git操作/テスト方針
  - `.spec-dock/current/discussions/env-vars-audit.md`: 公式情報と現状差分の調査メモ
  - `docker-compose.yml`: `environment:` / `volumes:` の確認
  - `Dockerfile`: `ENV` の確認
  - `host/sandbox`: Compose に注入している env の確認
  - `tests/sandbox_cli.test.sh`: 退行防止の主テスト
- 観測した現状（事実）:
  - `docker-compose.yml` が設定ディレクトリ系 env var を定義している一方、同じ場所は bind mount 済み（= env var がなくても“設定はその場所に存在する”）。
  - 一部 env var は公式に存在しない（または目的が異なる）ため、読み手に誤解を生む。
- 採用するパターン:
  - デフォルトの設定ディレクトリ + bind mount を正とし、Compose/Dockerfile でパスを “上書きしない”。
  - ユーザーがカスタムしたい場合のみ `.env` 等で “公式の正しい env var” を明示する。
- 採用しない/変更しない（理由）:
  - `.agent-home/` のディレクトリ構成変更（今回スコープ外）
  - ツール導入方法の変更（今回スコープ外）
- 影響範囲:
  - `docker-compose.yml` / `Dockerfile` / テスト（ファイル検査）に限定

## 判断材料/トレードオフ（Decision / Trade-offs） (任意)
- 方針: 「動作に寄与しない/冗長」env var は削除し、必要な上書きは “公式変数名” に寄せる
  - Pros: 誤解が減る / 変更の意味が明確 / 事故が減る
  - Cons: これまで暗黙に env var を参照していた運用があれば影響（ただし現状はデフォルト同一 or 未対応変数の可能性が高い）

## インターフェース契約（ここで固定） (任意)
- IF-ENV-001: “デフォルト運用”では、設定ディレクトリを env var で指定しない
  - Codex: `~/.codex` を使用（カスタムが必要なら `CODEX_HOME` または `codex -c/--config`）
  - Claude Code: `~/.claude` を使用（カスタムが必要なら `CLAUDE_CONFIG_DIR`）
  - Gemini CLI: `~/.gemini` を使用（現状 `GEMINI_CONFIG_DIR` は使わない）
  - OpenCode: `~/.config/opencode` を使用（カスタムが必要なら `OPENCODE_CONFIG_DIR` / `OPENCODE_CONFIG`）

## 変更計画（ファイルパス単位） (必須)
- 追加（Add）:
  - `.spec-dock/current/discussions/env-vars-audit.md`: 調査結果（根拠）
- 変更（Modify）:
  - `docker-compose.yml`: 削除対象 env var を `environment:` から削除（bind mount は維持）
  - `Dockerfile`: 削除対象 env var（`ENV`）を削除
  - `tests/sandbox_cli.test.sh`: 退行防止（ファイル検査）の追加/更新
- 削除（Delete）:
  - なし（この設計ではファイル削除は不要）
- 参照（Read only / context）:
  - `host/sandbox`: Compose 注入 env の前提理解のため
  - `.env.example`: 認証系 env var の扱い確認のため

### 削除対象（一次スコープ: “設定パス系”）
- `docker-compose.yml`:
  - `CODEX_CONFIG_DIR`（Codex の公式変数名ではない）
  - `GEMINI_CONFIG_DIR`（Gemini CLI のドキュメントに存在しない）
  - `OPENCODE_DATA_DIR` / `OPENCODE_CACHE_DIR`（OpenCode のドキュメントに存在しない）
  - `CLAUDE_CONFIG_DIR`（デフォルトと同一で冗長）
  - `OPENCODE_CONFIG_DIR`（デフォルトと同一で冗長）
- `Dockerfile`:
  - `CODEX_CONFIG_DIR`
  - `GEMINI_CONFIG_DIR`
  - `OPENCODE_CONFIG_DIR` / `OPENCODE_DATA_DIR` / `OPENCODE_CACHE_DIR`

### 削除対象（検討: “コンテナに渡す必要がない”）
- `docker-compose.yml` の `environment:` から以下を削除（Compose の補間には引き続き必要だが、コンテナ env としては未使用）:
  - `HOST_SANDBOX_PATH`
  - `HOST_USERNAME`
  - `HOST_PRODUCT_PATH`
  - `PRODUCT_NAME`
  - `PRODUCT_WORK_DIR`
  - `DEVCONTAINER`（Dockerfile で設定済みのため重複）
  - `DOCKER_HOST`（Dockerfile で設定済みのため重複）

## マッピング（要件 → 設計） (必須)
- AC-001 → `docker-compose.yml`, `Dockerfile` の env var 削除 + テストで固定
- AC-002 → `tests/sandbox_cli.test.sh`（既存の入口テスト + 新規ファイル検査）

## テスト戦略（最低限ここまで具体化） (任意)
- 追加/更新するテスト:
  - `tests/sandbox_cli.test.sh`: “禁止 env var が Dockerfile/docker-compose.yml に存在しない”を検査するテストを追加
- 実行コマンド:
  - `bash tests/sandbox_cli.test.sh`
  - （任意）`for f in tests/*.test.sh; do bash "$f"; done`

## 未確定事項（TBD） (必須)
- Q-001:
  - 質問: `docker-compose.yml` の `environment:` から `HOST_*` / `PRODUCT_*` を削除して良いか？（未使用なら露出しない）
  - 決定: A（削除する）
  - 理由: コンテナ内で参照箇所が無く、誤解/露出のノイズになるため
  - 影響範囲: `docker-compose.yml` / AC-001
- Q-002:
  - 質問: “設定パス系”以外（例: `DOCKER_CONFIG`, `DOCKER_HOST`, `DEVCONTAINER`, `TMUX_SESSION_NAME`）も同時に整理するか？
  - 決定: A（Dockerfile 側は対象外。必要なら別タスクで追加調査する）
  - 補足: `docker-compose.yml` 側の重複定義（`DEVCONTAINER` / `DOCKER_HOST`）はノイズとして削除した
  - 影響範囲: `Dockerfile` / `docker-compose.yml`

## 省略/例外メモ (必須)
- UML 等の図は本タスクでは不要のため省略
