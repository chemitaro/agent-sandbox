---
種別: 実装計画書
機能ID: "FEAT-SANDBOX-CODEX-RUNTIME-TRUST-001"
機能名: "sandbox codex の runtime trust 注入（最大権限デフォルトと skills 有効化）"
関連Issue: []
状態: "draft"
作成者: "Codex CLI"
最終更新: "2026-01-25"
依存: ["requirement.md", "design.md"]
---

# FEAT-SANDBOX-CODEX-RUNTIME-TRUST-001 sandbox codex の runtime trust 注入（最大権限デフォルトと skills 有効化） — 実装計画（TDD: Red → Green → Refactor）

## この計画で満たす要件ID (必須)
- 対象AC: AC-001, AC-002, AC-003, AC-004
- 対象EC: EC-001, EC-002, EC-003
- 対象制約:
  - 永続 config を作成/編集しない（MUST NOT）
  - テストは stub 方式（Docker/Git の実依存なし）
  - 禁止 Git コマンド（`git add/commit/push/merge`）は実行しない

## ステップ一覧（観測可能な振る舞い） (必須)
- [ ] S01: 既存テストを新仕様へ置換する（永続 config を書かない）
- [ ] S02: git repo で `sandbox codex` が defaults + trust を注入する
- [ ] S03: 非 git で `sandbox codex` が effective dir を trust 注入する
- [ ] S04: ユーザー指定 `-C/-a/-s` を尊重し二重指定しない
- [ ] S05: user `-c/--config projects...` をエラーにする
- [ ] S06: `sandbox codex -h` のヘルプに注意書きを追加する
- [ ] S07: 手動受け入れ（AC-002）を実施し report に記録する

### 要件 ↔ ステップ対応表 (必須)
- AC-001 → S02
- AC-002 → S07
- AC-003 → S03
- AC-004 → S04
- EC-001 → S03（git 失敗 → fallback）
- EC-002 → S02/S03（mount-root 外 → trust 注入スキップ + 警告）
- EC-003 → S05
- 制約（永続 config 編集禁止） → S01/S02/S03（テストで担保）
- 制約（stub テスト） → 全ステップ（`tests/sandbox_cli.test.sh`）

---

## 実装ステップ（各ステップは“観測可能な振る舞い”を1つ） (必須)

### S01 — 既存テストを新仕様へ置換する（永続 config を書かない） (必須)
- 対象: 制約（永続 config 編集禁止）
- 設計参照:
  - 対象IF: IF-001（永続 config に触れない）
  - 対象テスト: `tests/sandbox_cli.test.sh`
- このステップで「追加しないこと（スコープ固定）」:
  - `sandbox shell` の挙動変更（本ステップはテスト整備のみ）

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に S01 を登録する
  - （調査）既存テスト失敗点の確認
  - （Red）テストを新仕様へ置換（失敗するテストを作る）
  - （Green）テストが通る状態に調整（実装変更は行わない）
  - （品質ゲート）`bash tests/sandbox_cli.test.sh`
  - （報告）`.spec-dock/current/report.md` 更新
  - （コミット）**実施しない**（禁止コマンド）

#### 期待する振る舞い（テストケース） (必須)
- Given: `sandbox shell` / `sandbox codex` をテスト stub 環境で実行する
- When: 実行後に `.agent-home/.codex/config.toml` を確認する
- Then: 当該ファイルは **作成されない**（永続 config を触らない）
- 観測点: テスト内のファイル存在チェック
- 追加/更新するテスト:
  - `tests/sandbox_cli.test.sh`: `shell_trusts_git_repo_root_for_codex` を削除/置換し、新仕様のテスト名に変更

#### Red（失敗するテストを先に書く） (任意)
- 期待する失敗:
  - 現在の `shell_trusts_git_repo_root_for_codex` が「config.toml が作られること」を期待して失敗している

#### Green（最小実装） (任意)
- 変更予定ファイル:
  - Modify: `tests/sandbox_cli.test.sh`
- 実装方針:
  - 既存の failing テストを「永続 config を作らない」仕様に合わせて置換する

#### Refactor（振る舞い不変で整理） (任意)
- 目的:
  - テスト名と意図を分かりやすくする（将来の誤読を防ぐ）

#### ステップ末尾（省略しない） (必須)
- [ ] `bash tests/sandbox_cli.test.sh` を実行し、成功した
- [ ] `.spec-dock/current/report.md` に実行コマンド/結果/変更ファイルを記録した
- [ ] `update_plan` を更新し、S01 を完了にした
- [ ] `git commit` は実施しない（禁止コマンド）

---

### S02 — git repo で `sandbox codex` が defaults + trust を注入する (必須)
- 対象: AC-001
- 設計参照:
  - 対象IF: IF-001/IF-002/IF-003（design.md）
  - 対象テスト: `tests/sandbox_cli.test.sh`
- このステップで「追加しないこと（スコープ固定）」:
  - 非 git の詳細（S03 で扱う）
  - ユーザー指定の重複回避（S04 で扱う）

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に S02 を登録する（調査/Red/Green/Refactor/品質ゲート/報告/コミット）

#### 期待する振る舞い（テストケース） (必須)
- Given: git repo 配下で `SANDBOX_CODEX_NO_TMUX=1 sandbox codex` を実行する（compose/git は stub）
- When: `codex resume` が起動される
- Then:
  - `codex resume` に `-a never` / `-s danger-full-access` / `-C .` が付与される（ユーザー未指定のため）
  - `-c projects={\"/srv/mount/<trust1>\"={trust_level=\"trusted\"},\"/srv/mount/<trust2>\"={trust_level=\"trusted\"}}` が付与される
    - trust1: `--show-toplevel` 由来（worktree root）
    - trust2: `--git-common-dir` 親（root git project for trust）
  - `.agent-home/.codex/config.toml` は作成されない
- 観測点: compose stub ログ（CMD の引数列）+ ファイル存在チェック

#### Red（失敗するテストを先に書く） (任意)
- 期待する失敗:
  - 現状の `sandbox codex` は `codex resume` を起動するが、上記の `-a/-s/-C/-c` を付与しないためテストが落ちる

#### Green（最小実装） (任意)
- 変更予定ファイル:
  - Modify: `host/sandbox`
  - Modify: `tests/sandbox_cli.test.sh`
- 実装方針:
  - `CODEX_ARGS` を解析し、ユーザー未指定の `-a/-s/-C` を inject
  - `effective_host_dir` を決め、git から trust dirs を計算して `-c projects=...` を inject
  - `run_compose_exec_codex` に渡す引数列を `FINAL_CODEX_ARGS` に置換

#### Refactor（振る舞い不変で整理） (任意)
- 目的: bash 関数分割（IF-001/002/003）と quoting の安全性確保

#### ステップ末尾（省略しない） (必須)
- [ ] `bash tests/sandbox_cli.test.sh` を実行し、成功した
- [ ] `.spec-dock/current/report.md` に実行コマンド/結果/変更ファイルを記録した
- [ ] `update_plan` を更新し、S02 を完了にした
- [ ] `git commit` は実施しない（禁止コマンド）

---

### S03 — 非 git で `sandbox codex` が effective dir を trust 注入する (必須)
- 対象: AC-003, EC-001
- 設計参照:
  - 対象IF: IF-001/IF-002/IF-003
  - 対象テスト: `tests/sandbox_cli.test.sh`

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に S03 を登録する

#### 期待する振る舞い（テストケース） (必須)
- Given: `.git` が無いディレクトリで `SANDBOX_CODEX_NO_TMUX=1 sandbox codex` を実行する（compose は stub、git は呼ばれない/失敗する）
- When: `codex resume` が起動される
- Then:
  - `-a never -s danger-full-access -C .` が付与される
  - trust 注入として `-c projects={\"/srv/mount\"={trust_level=\"trusted\"}}`（effective `--cd` = `.` のため）が付与される
  - `sandbox codex` は exit code 0 で動作する
- 観測点: compose stub ログ

#### ステップ末尾（省略しない） (必須)
- [ ] `bash tests/sandbox_cli.test.sh` を実行し、成功した
- [ ] `.spec-dock/current/report.md` を更新した
- [ ] `update_plan` を更新した
- [ ] `git commit` は実施しない（禁止コマンド）

---

### S04 — ユーザー指定 `-C/-a/-s` を尊重し二重指定しない (必須)
- 対象: AC-004
- 設計参照:
  - 引数の組み立てルール（固定）: `.spec-dock/current/design.md`
  - 対象テスト: `tests/sandbox_cli.test.sh`

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に S04 を登録する

#### 期待する振る舞い（テストケース） (必須)
- Given: ユーザーが `sandbox codex -- <codex args...>` で以下を指定する
  - `--cd=<dir>`（または `-C<dir>`）
  - `--ask-for-approval=on-request`（または `-a on-request`）
  - `--sandbox=workspace-write`（または `-s workspace-write`）
- When: `sandbox codex` が `codex resume` を起動する
- Then:
  - `-C .` / `-a never` / `-s danger-full-access` は **注入されない**
  - ユーザー指定の `-C/-a/-s` がそのまま残る
- 観測点: compose stub ログ

#### ステップ末尾（省略しない） (必須)
- [ ] `bash tests/sandbox_cli.test.sh` を実行し、成功した
- [ ] `.spec-dock/current/report.md` を更新した
- [ ] `update_plan` を更新した
- [ ] `git commit` は実施しない（禁止コマンド）

---

### S05 — user `-c/--config projects...` をエラーにする (必須)
- 対象: EC-003
- 設計参照:
  - 引数の組み立てルール（固定）: `.spec-dock/current/design.md`
  - 対象テスト: `tests/sandbox_cli.test.sh`

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に S05 を登録する

#### 期待する振る舞い（テストケース） (必須)
- Given: `sandbox codex -- -c projects={}` を実行する
- When: `sandbox codex` が user args を検査する
- Then:
  - exit code が 1（非0）
  - stderr に「`projects` override は禁止」等の説明が出る
- 観測点: exit code / stderr

#### ステップ末尾（省略しない） (必須)
- [ ] `bash tests/sandbox_cli.test.sh` を実行し、成功した
- [ ] `.spec-dock/current/report.md` を更新した
- [ ] `update_plan` を更新した
- [ ] `git commit` は実施しない（禁止コマンド）

---

### S06 — `sandbox codex -h` のヘルプに注意書きを追加する (必須)
- 対象: 非交渉制約（運用の明確化）
- 設計参照:
  - 変更計画: `host/sandbox` の `print_help_codex` 更新

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に S06 を登録する

#### 期待する振る舞い（テストケース） (必須)
- Given: `sandbox codex -h` を実行する
- When: ヘルプが表示される
- Then: 次が明記されている
  - デフォルトで `-a never -s danger-full-access` を付与すること
  - runtime trust 注入を行うこと（永続 config は編集しない）
  - 非 git でも trust 注入すること（隔離環境前提の注意）
- 観測点: stdout（ヘルプ文）

#### ステップ末尾（省略しない） (必須)
- [ ] `bash tests/sandbox_cli.test.sh` を実行し、成功した
- [ ] `.spec-dock/current/report.md` を更新した
- [ ] `update_plan` を更新した
- [ ] `git commit` は実施しない（禁止コマンド）

---

### S07 — 手動受け入れ（AC-002）を実施し report に記録する (必須)
- 対象: AC-002
- 設計参照:
  - 手順書: `.spec-dock/current/discussions/manual-acceptance-ac002.md`

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に S07 を登録する

#### 期待する振る舞い（テストケース） (必須)
- Given: `.codex/skills/**/SKILL.md` を持つ git repo がある
- When: 手順書に従って `sandbox codex` を起動し、Codex で `/skills` を実行する
- Then: repo-scope skills が Skills UI に表示される
- 観測点: 手動確認（画面）+ `.spec-dock/current/report.md` 記録

#### ステップ末尾（省略しない） (必須)
- [ ] 手動受け入れを実施し、`.spec-dock/current/report.md` に結果を記録した
- [ ] `update_plan` を更新した
- [ ] `git commit` は実施しない（禁止コマンド）

---

## 未確定事項（TBD） (必須)
- 該当なし

## 完了条件（Definition of Done） (必須)
- 対象AC/ECがすべて満たされる（AC-002 は手動受け入れで確認）
- MUST NOT / OUT OF SCOPE を破っていない（追加機能を入れていない）
- 品質ゲート（`bash tests/sandbox_cli.test.sh`）が満たされている

## 省略/例外メモ (必須)
- 該当なし
