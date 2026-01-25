---
種別: 実装計画書
機能ID: "FEAT-CODEX-TRUST-001"
機能名: "コンテナ内Codexのスキル認識を安定化（複数worktree並行運用）"
関連Issue: ["N/A"]
状態: "draft"
作成者: "Codex CLI"
最終更新: "2026-01-24"
依存: ["requirement.md", "design.md"]
---

# FEAT-CODEX-TRUST-001 コンテナ内Codexのスキル認識を安定化（複数worktree並行運用） — 実装計画（TDD: Red → Green → Refactor）

## この計画で満たす要件ID (必須)
- 対象AC: AC-001, AC-002, AC-003, AC-004
- 対象EC: EC-001, EC-002
- 対象制約:
  - MUST NOT: 外部ツールによる `config.toml` の機械編集 / runtime overrides 注入 / system config 導入（`@.spec-dock/current/requirement.md`）

## ステップ一覧（観測可能な振る舞い） (必須)
- [ ] S01: `sandbox` が Codex 設定を書き換えない
- [ ] S02: `sandbox codex` が `codex resume --cd .` を実行する
- [ ] S03: ユーザー指定 `--cd/-C` なら `--cd .` を付与しない
- [ ] S04: （任意）ヘルプに運用メモを追記する
- [ ] S05: 手動受け入れ（skills 認識）を記録する

### 要件 ↔ ステップ対応表 (必須)
- AC-001 → S02, S05（proxy: `--cd` 付与 + 手動確認の記録）
- AC-002 → S02, S03, S05（proxy: `--cd` 付与 + 手動確認の記録）
- AC-003 → S01（否定テストで担保）
- AC-004 → S02, S03, S05（proxy: `--cd` 付与 + 手動確認の記録）
- EC-001 → S01, S02, S03（`/srv/mount` 一括 trust を前提にしない）
- EC-002 → S02（既存のエラー表示があれば維持。追加対応は OUT OF SCOPE）
- 非交渉制約（MUST NOT）→ S01, S02, S03（テスト・実装で逸脱しない）

---

## 実装ステップ（各ステップは“観測可能な振る舞い”を1つ） (必須)

### S01 — `sandbox shell` / `sandbox codex` が Codex 設定（`config.toml`）を書き換えない (必須)
- 対象: AC-003 / EC-001
- 設計参照:
  - 対象IF/API:
    - `host/sandbox::run_compose_exec`（`shell` 導線）
    - `host/sandbox::run_compose_exec_codex`（`codex` 導線）
  - 対象テスト:
    - `tests/sandbox_cli.test.sh::shell_trusts_git_repo_root_for_codex`（期待を反転 / 必要ならリネーム）
    - `tests/sandbox_cli.test.sh::codex_does_not_write_codex_config_toml`（新規）
- このステップで「追加しないこと（スコープ固定）」:
  - Codex trust を自動登録する実装（`config.toml` の編集）を追加しない

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に、このステップの作業ステップ（調査/Red/Green/Refactor/品質ゲート/報告/コミット）を登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: `sandbox shell` または `sandbox codex` を `--mount-root` / `--workdir` 付きで起動する（workdir は mount-root 配下のサブディレクトリ）
- When: `sandbox` が `docker compose exec ...` を実行する
- Then:
  - `.agent-home/.codex/config.toml` が無い場合は **作成しない**
  - `.agent-home/.codex/config.toml` がある場合は **内容を変更しない**
- 観測点: `tests/sandbox_cli.test.sh` 内でのファイル存在チェック（否定）と、既存ファイルがある場合の内容比較
- 追加/更新するテスト:
  - `tests/sandbox_cli.test.sh::shell_trusts_git_repo_root_for_codex`（「作る」期待を削除し、作成/変更しないことを検証）
  - `tests/sandbox_cli.test.sh::codex_does_not_write_codex_config_toml`（新規: 作成/変更しないことを検証）

#### Red（失敗するテストを先に書く） (任意)
- 期待する失敗:
  - 現状テストは `config.toml` の作成を要求しているため失敗する → 要件（AC-003）に一致する否定テストへ修正する

#### Green（最小実装） (任意)
- 変更予定ファイル:
  - Modify: `tests/sandbox_cli.test.sh`
- 実装方針:
  - `shell_trusts_git_repo_root_for_codex` の「作成/追記」検証を削除し、`config.toml` を作成/変更しないことを確認する
  - `sandbox codex` に対しても同様に、`config.toml` を作成/変更しないことを確認するテストを追加する

#### Refactor（振る舞い不変で整理） (任意)
- 目的:
  - テスト名/本文が要件（AC-003）に整合するようにする（必要なら関数名も変更）

#### ステップ末尾（省略しない） (必須)
- [ ] `bash tests/sandbox_cli.test.sh` を実行し、成功した
- [ ] `.spec-dock/current/report.md` に実行コマンド/結果/変更ファイルを記録した
- [ ] `update_plan` を更新し、このステップの作業ステップを完了にした
- [ ] コミットは実施しない（禁止コマンドのため）。`report.md` に理由を記録した

---

### S02 — `sandbox codex` が `codex resume --cd .` を実行する（proxy 観測点） (必須)
- 対象: AC-001 / AC-002 / AC-004 / EC-001
- 設計参照:
  - 対象IF/API: IF-001（`host/sandbox::run_compose_exec_codex`）
  - 対象テスト:
    - `tests/sandbox_cli.test.sh::codex_inner_runs_codex_resume_and_returns_to_zsh`
    - `tests/sandbox_cli.test.sh::codex_inner_without_double_dash_uses_default_args`
- このステップで「追加しないこと（スコープ固定）」:
  - trust の自動登録（`config.toml` 編集）を追加しない
  - runtime overrides（`--config` 等）を追加しない

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に、このステップの作業ステップ（調査/Red/Green/Refactor/品質ゲート/報告/コミット）を登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: `SANDBOX_CODEX_NO_TMUX=1` で `sandbox codex` を実行する
- When: `sandbox` がコンテナ内で `codex resume ...` を実行する
- Then: `docker compose exec ... codex resume --cd . ...` がログに残る（`--cd .` が `resume` の後ろ）
- 観測点: `compose.log`（stubs）への出力文字列
- 追加/更新するテスト:
  - `tests/sandbox_cli.test.sh::codex_inner_runs_codex_resume_and_returns_to_zsh`（`--cd` の存在を追加）
  - `tests/sandbox_cli.test.sh::codex_inner_without_double_dash_uses_default_args`（`--cd` の存在を追加）

#### Red（失敗するテストを先に書く） (任意)
- 期待する失敗:
  - 現状は `codex resume` なので、`--cd` を期待すると失敗する

#### Green（最小実装） (任意)
- 変更予定ファイル:
  - Modify: `tests/sandbox_cli.test.sh`
  - Modify: `host/sandbox`
- 実装方針:
  - `host/sandbox::run_compose_exec_codex` の `codex resume` を `codex resume --cd .` に変更する（ユーザー指定が無い場合は常に）

#### Refactor（振る舞い不変で整理） (任意)
- 目的:
  - 引数のクォート/受け渡しの安全性を維持する（`"$@"` の扱いを壊さない）

#### ステップ末尾（省略しない） (必須)
- [ ] `bash tests/sandbox_cli.test.sh` を実行し、成功した
- [ ] `.spec-dock/current/report.md` に実行コマンド/結果/変更ファイルを記録した
- [ ] `update_plan` を更新し、このステップの作業ステップを完了にした
- [ ] コミットは実施しない（禁止コマンドのため）。`report.md` に理由を記録した

---

### S03 — ユーザー指定 `--cd/-C` がある場合は `--cd .` を付与しない (必須)
- 対象: AC-002 / AC-004 / EC-001
- 設計参照:
  - 対象IF/API: IF-001（`--cd` 重複回避）
  - 対象テスト: `tests/sandbox_cli.test.sh`（新規テスト追加）
- このステップで「追加しないこと（スコープ固定）」:
  - trust の自動登録（`config.toml` 編集）を追加しない

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に、このステップの作業ステップ（調査/Red/Green/Refactor/品質ゲート/報告/コミット）を登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: ユーザーが `sandbox codex -- --cd=/tmp` または `sandbox codex -- -C/tmp` のように作業ディレクトリを指定する
- When: `sandbox` がコンテナ内で `codex resume ...` を実行する
- Then: `--cd .` は付与されず、ユーザー指定の `--cd...` / `-C...` がそのまま渡る
- 観測点: `compose.log`（stubs）への出力文字列（`--cd\\ .` が存在しない）
- 追加/更新するテスト:
  - `tests/sandbox_cli.test.sh::codex_inner_respects_user_cd_arg`（新規）

#### Red（失敗するテストを先に書く） (任意)
- 期待する失敗:
  - S02 実装のままだと `--cd .` が常に付与されるため、重複回避の期待で失敗する

#### Green（最小実装） (任意)
- 変更予定ファイル:
  - Modify: `tests/sandbox_cli.test.sh`
  - Modify: `host/sandbox`
- 実装方針:
  - `run_compose_exec_codex` の引数（`CODEX_ARGS`）を走査し、以下を検知したら `--cd .` を付与しない:
    - `--cd` / `--cd=<path>`
    - `-C` / `-C<path>`

#### Refactor（振る舞い不変で整理） (任意)
- 目的:
  - `--cd` 検知ロジックを小さく保ち、過剰な一般化は避ける

#### ステップ末尾（省略しない） (必須)
- [ ] `bash tests/sandbox_cli.test.sh` を実行し、成功した
- [ ] `.spec-dock/current/report.md` に実行コマンド/結果/変更ファイルを記録した
- [ ] `update_plan` を更新し、このステップの作業ステップを完了にした
- [ ] コミットは実施しない（禁止コマンドのため）。`report.md` に理由を記録した

---

### S04 — （任意）ヘルプに運用メモを追記する (任意)
- 対象: AC-001（理解補助）
- 設計参照: `@.spec-dock/current/design.md`（手動確認 / sandbox shell の運用メモ）
- このステップで「追加しないこと（スコープ固定）」:
  - trust の自動登録（`config.toml` 編集）を追加しない

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に、このステップの作業ステップ（調査/Red/Green/Refactor/品質ゲート/報告）を登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: `sandbox codex --help` を実行する
- When: help が表示される
- Then: trust は Codex 標準フローに委ねる旨、必要なら `codex resume --cd .` を使う旨が読み取れる
- 観測点: 標準出力
- 追加/更新するテスト（任意）:
  - `tests/sandbox_cli.test.sh`（必要なら `assert_stdout_contains` を追加）

#### Red（失敗するテストを先に書く） (任意)
- 期待する失敗:
  - help に新しい断片を追加する場合、テストは先に失敗させる

#### Green（最小実装） (任意)
- 変更予定ファイル:
  - Modify: `host/sandbox`
  - （任意）Modify: `tests/sandbox_cli.test.sh`
- 実装方針:
  - `host/sandbox` の `print_help_codex` に短い運用メモを追記する

#### Refactor（振る舞い不変で整理） (任意)
- 目的:
  - help の文面を短く、誤解が生まれにくい表現に整える

#### ステップ末尾（省略しない） (必須)
- [ ] （該当する場合）`bash tests/sandbox_cli.test.sh` を実行し、成功した
- [ ] `.spec-dock/current/report.md` に実行コマンド/結果/変更ファイルを記録した
- [ ] `update_plan` を更新し、このステップの作業ステップを完了にした

---

### S05 — 手動受け入れ（skills 認識）を `report.md` に記録する (必須)
- 対象: AC-001 / AC-002 / AC-004
- 設計参照:
  - `@.spec-dock/current/design.md`（手動確認（受け入れ手順））
  - `@.spec-dock/current/discussions/codex_trust_standard_operation.md`（trust / restart 要否）
- このステップで「追加しないこと（スコープ固定）」:
  - 手動受け入れを自動化するための新機能追加（OUT OF SCOPE）

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に、このステップの作業ステップ（手動確認/報告）を登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: 対象 worktree に `.codex/skills/**/SKILL.md` が存在する
- When: `sandbox codex`（および必要なら `sandbox shell` → `codex resume --cd .`）で Codex を起動し、trust 促しがあれば承認する
- Then:
  - 必要なら再起動後に、worktree 固有の skill が利用できる
  - 実施結果（worktree パス / 表示された trust 促し / 再起動要否 / 確認できた skill 名 等）が `report.md` に残る
- 観測点: 人間による確認結果（ログ/スクショ/要約）
- 追加/更新するテスト: なし（手動）

#### ステップ末尾（省略しない） (必須)
- [ ] `@.spec-dock/current/design.md` の手順に沿って手動確認した
- [ ] `.spec-dock/current/report.md` に実行手順/結果を記録した
- [ ] `update_plan` を更新し、このステップの作業ステップを完了にした

---

## 未確定事項（TBD） (必須)
- 該当なし

## 完了条件（Definition of Done） (必須)
- 対象AC/ECがすべて満たされ、テストで保証されている
- MUST NOT / OUT OF SCOPE を破っていない（追加機能を入れていない）
- 品質ゲート（テスト）が満たされている
- `@.spec-dock/current/design.md` の手順で手動受け入れを実施し、`.spec-dock/current/report.md` に結果が記録されている（S05）

## 省略/例外メモ (必須)
- コミット運用:
  - spec-dock ガイド上はステップ末尾のコミットを推奨するが、この実行環境では `git commit` 等が禁止コマンドのため、コミットは行わない（`report.md` に理由を記録する）
