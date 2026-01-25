---
種別: 実装計画書
機能ID: "SBX-CODEX-AUTO-BOOTSTRAP"
機能名: "sandbox codex: Trust状態に応じた自動Bootstrap/YOLO切替"
関連Issue: []
状態: "draft"
作成者: "Codex CLI (GPT-5.2)"
最終更新: "2026-01-26"
依存: ["requirement.md", "design.md"]
---

# SBX-CODEX-AUTO-BOOTSTRAP sandbox codex: Trust状態に応じた自動Bootstrap/YOLO切替 — 実装計画（TDD: Red → Green → Refactor）

## この計画で満たす要件ID (必須)
- 対象AC: AC-001, AC-002, AC-003
- 対象EC: EC-001, EC-002, EC-003
- 対象制約:
  - sandbox が `config.toml` の `projects` を機械編集しない（MUST NOT）
  - tests は stub のみ（実Docker/実Git を呼ばない）

## ステップ一覧（観測可能な振る舞い） (必須)
- [ ] S01: `sandbox shell` が Codex config を生成しない（回帰防止）
- [ ] S02: `sandbox codex` が常に `--cd <container_workdir>` を付与する
- [ ] S03: Trust済みGitでは YOLO で起動する（+ `--cd`）
- [ ] S04: 未TrustGitでは bootstrap で起動し、Trust案内を出す（+ `--cd`）
- [ ] S05: 非Gitでは YOLO + `--skip-git-repo-check` で起動する（+ `--cd`）
- [ ] S06: `.git` はあるが rev-parse 失敗時は bootstrap + 警告で起動する（+ `--cd`）
- [ ] S07: 競合引数はエラーで拒否し、compose を呼ばない
- [ ] S08: 手動受け入れ（bootstrap→trust→yolo）を実施して report に残す

### 要件 ↔ ステップ対応表 (必須)
- AC-001 → S03
- AC-002 → S04
- AC-003 → S05
- EC-001 → S04（未Trust判定として bootstrap）
- EC-002 → S06
- EC-003 → S04（`trust_level != trusted` は未Trust扱い）
- MUST NOT（config機械編集禁止）→ S01（回帰防止）+ 全ステップ（実装方針）

---

## 実装ステップ（各ステップは“観測可能な振る舞い”を1つ） (必須)

### S01 — `sandbox shell` が Codex config を生成しない（回帰防止） (必須)
- 対象: MUST NOT（config機械編集禁止の回帰防止）
- 設計参照:
  - 対象IF: なし（現状確認の回帰防止）
  - 対象テスト: `tests/sandbox_cli.test.sh::shell_does_not_write_codex_config`
- このステップで「追加しないこと（スコープ固定）」:
  - `sandbox shell` の挙動変更

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に作業ステップを登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: `sandbox shell` を実行できるスタブ環境
- When: `sandbox shell --mount-root <root> --workdir <workdir>` を実行する
- Then:
  - `.agent-home/.codex/config.toml` が新規作成されない（または既存が変更されない）
- 観測点: ファイルの存在/内容（diff） + docker compose stub log
- 追加/更新するテスト: `tests/sandbox_cli.test.sh::shell_does_not_write_codex_config`

#### Red（失敗するテストを先に書く） (任意)
- 既存の `shell_trusts_git_repo_root_for_codex` を、意図に沿う名称/期待値へ変更する（現状テストは要件と矛盾）

#### Green（最小実装） (任意)
- 変更予定ファイル:
  - Modify: `tests/sandbox_cli.test.sh`
- 実装方針:
  - `sandbox shell` 自体は触らず、テストを “非生成/非変更” の回帰防止にする

#### ステップ末尾（省略しない） (必須)
- [ ] `bash tests/sandbox_cli.test.sh` を実行し成功した
- [ ] `.spec-dock/current/report.md` に実行コマンド/結果/変更ファイルを記録した
- [ ] `update_plan` を更新し、このステップを完了にした
- [ ] コミットは実施しない（禁止コマンドのため）

---

### S02 — `sandbox codex` が常に `--cd <container_workdir>` を付与する (必須)
- 対象: AC-001/AC-002/AC-003（共通要件）
- 設計参照:
  - 対象IF: IF-003
  - 対象テスト: `tests/sandbox_cli.test.sh::codex_inner_adds_cd_to_resume`
- このステップで「追加しないこと（スコープ固定）」:
  - Trust 判定や YOLO 切替の実装（S03以降で実施）

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に作業ステップを登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: `.git` が無いディレクトリ（非Git）で `sandbox codex` を実行する
- When: `sandbox codex --mount-root <root> --workdir <workdir>` を実行する（inner: `SANDBOX_CODEX_NO_TMUX=1`）
- Then:
  - docker compose stub log の `codex resume` 引数に `--cd <container_workdir>` が含まれる
- 観測点: docker compose stub log
- 追加/更新するテスト: `tests/sandbox_cli.test.sh::codex_inner_adds_cd_to_resume`

#### Green（最小実装） (任意)
- 変更予定ファイル:
  - Modify: `host/sandbox`
  - Modify: `tests/sandbox_cli.test.sh`
- 実装方針:
  - `run_compose_exec_codex` へ渡す `CODEX_ARGS` に、先頭で `--cd "$container_workdir"` を注入する

#### ステップ末尾（省略しない） (必須)
- [ ] `bash tests/sandbox_cli.test.sh` を実行し成功した
- [ ] `.spec-dock/current/report.md` を更新した
- [ ] `update_plan` を更新した
- [ ] コミットは実施しない（禁止コマンドのため）

---

### S03 — Trust済みGitでは YOLO で起動する（+ `--cd`） (必須)
- 対象: AC-001
- 設計参照:
  - 対象IF: IF-001, IF-002, IF-003
  - 対象テスト: `tests/sandbox_cli.test.sh::codex_inner_runs_yolo_when_trusted`
- このステップで「追加しないこと（スコープ固定）」:
  - 未Trust時の Trust案内（S04）

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に作業ステップを登録した

#### 期待する振る舞い（テストケース） (必須)
- Given:
  - `workdir` が Git 配下（`<root>/repo/subdir`）で、`<root>/repo/.git` が存在する
  - `git -C <workdir> rev-parse --show-toplevel` が `<root>/repo` を返す（stub）
  - `.agent-home/.codex/config.toml` に `[projects.\"/srv/mount/repo\"] trust_level=\"trusted\"` がある（fixture）
- When: `sandbox codex --mount-root <root> --workdir <root>/repo/subdir` を実行する
- Then:
  - `codex resume` 引数に `--sandbox danger-full-access` と `--ask-for-approval never` が含まれる
  - `--cd /srv/mount/repo/subdir` が含まれる
- 観測点: docker compose stub log
- 追加/更新するテスト: `tests/sandbox_cli.test.sh::codex_inner_runs_yolo_when_trusted`

#### Green（最小実装） (任意)
- 変更予定ファイル:
  - Modify: `host/sandbox`
  - Modify: `tests/sandbox_cli.test.sh`
- 実装方針:
  - show-toplevel を trust_key に変換し、config.toml から `trust_level="trusted"` を判定
  - trusted の場合のみ YOLO 引数を注入

#### ステップ末尾（省略しない） (必須)
- [ ] `bash tests/sandbox_cli.test.sh` を実行し成功した
- [ ] `.spec-dock/current/report.md` を更新した
- [ ] `update_plan` を更新した
- [ ] コミットは実施しない（禁止コマンドのため）

---

### S04 — 未TrustGitでは bootstrap で起動し、Trust案内を出す（+ `--cd`） (必須)
- 対象: AC-002, EC-001, EC-003
- 設計参照:
  - 対象IF: IF-001, IF-002, IF-003
  - 対象テスト: `tests/sandbox_cli.test.sh::codex_inner_runs_bootstrap_when_untrusted_and_prints_hint`
- このステップで「追加しないこと（スコープ固定）」:
  - 非Gitの `--skip-git-repo-check`（S05）

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に作業ステップを登録した

#### 期待する振る舞い（テストケース） (必須)
- Given:
  - Git show-toplevel は成功する（stub）
  - `config.toml` が (a) 無い、(b) 対象repoの entry が無い、(c) `trust_level!="trusted"` のいずれか
- When: `sandbox codex ...` を実行する
- Then:
  - `codex resume` 引数に YOLO 引数（`--sandbox ...`, `--ask-for-approval ...`）が含まれない
  - stderr に “Trust して再実行” の案内が出る
  - `--cd ...` は含まれる
- 観測点: docker compose stub log / stderr
- 追加/更新するテスト: `tests/sandbox_cli.test.sh::codex_inner_runs_bootstrap_when_untrusted_and_prints_hint`

#### Green（最小実装） (任意)
- 変更予定ファイル:
  - Modify: `host/sandbox`
  - Modify: `tests/sandbox_cli.test.sh`
- 実装方針:
  - `is_codex_project_trusted` を “strict” にし、判定できない場合は未Trust扱いにする
  - 未Trust時は stderr で案内しつつ bootstrap 起動する

#### ステップ末尾（省略しない） (必須)
- [ ] `bash tests/sandbox_cli.test.sh` を実行し成功した
- [ ] `.spec-dock/current/report.md` を更新した
- [ ] `update_plan` を更新した
- [ ] コミットは実施しない（禁止コマンドのため）

---

### S05 — 非Gitでは YOLO + `--skip-git-repo-check` で起動する（+ `--cd`） (必須)
- 対象: AC-003
- 設計参照:
  - 対象IF: IF-001, IF-003
  - 対象テスト: `tests/sandbox_cli.test.sh::codex_inner_non_git_runs_yolo_with_skip_git_repo_check`
- このステップで「追加しないこと（スコープ固定）」:
  - `.git` があるケース（S06）

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に作業ステップを登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: `.git` が存在しないディレクトリ
- When: `sandbox codex ...` を実行する
- Then:
  - `codex resume` 引数に `--skip-git-repo-check` が含まれる
  - `--sandbox danger-full-access` と `--ask-for-approval never` が含まれる
  - `--cd ...` は含まれる
- 観測点: docker compose stub log
- 追加/更新するテスト: `tests/sandbox_cli.test.sh::codex_inner_non_git_runs_yolo_with_skip_git_repo_check`

#### Green（最小実装） (任意)
- 変更予定ファイル:
  - Modify: `host/sandbox`
  - Modify: `tests/sandbox_cli.test.sh`
- 実装方針:
  - `find_git_marker` が false の場合は non-git として扱い、YOLO + `--skip-git-repo-check` を付与する

#### ステップ末尾（省略しない） (必須)
- [ ] `bash tests/sandbox_cli.test.sh` を実行し成功した
- [ ] `.spec-dock/current/report.md` を更新した
- [ ] `update_plan` を更新した
- [ ] コミットは実施しない（禁止コマンドのため）

---

### S06 — `.git` はあるが rev-parse 失敗時は bootstrap + 警告で起動する（+ `--cd`） (必須)
- 対象: EC-002
- 設計参照:
  - 対象IF: IF-001
  - 対象テスト: `tests/sandbox_cli.test.sh::codex_inner_git_rev_parse_failure_warns_and_runs_bootstrap`
- このステップで「追加しないこと（スコープ固定）」:
  - Trust 判定の精度改善（必要なら後続ステップで）

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に作業ステップを登録した

#### 期待する振る舞い（テストケース） (必須)
- Given:
  - `.git` は存在する
  - `git rev-parse --show-toplevel` が失敗する（stub）
- When: `sandbox codex ...` を実行する
- Then:
  - stderr に “failed to detect git root (rev-parse)” 等の警告が出る
  - `codex resume` 引数に YOLO 引数が含まれない（bootstrap）
  - `--cd ...` は含まれる
- 観測点: stderr / docker compose stub log
- 追加/更新するテスト: `tests/sandbox_cli.test.sh::codex_inner_git_rev_parse_failure_warns_and_runs_bootstrap`

#### Green（最小実装） (任意)
- 変更予定ファイル:
  - Modify: `host/sandbox`
  - Modify: `tests/sandbox_cli.test.sh`
- 実装方針:
  - `.git` は見つかるが rev-parse が失敗した場合は、trust 判定を諦め bootstrap にフォールバックする

#### ステップ末尾（省略しない） (必須)
- [ ] `bash tests/sandbox_cli.test.sh` を実行し成功した
- [ ] `.spec-dock/current/report.md` を更新した
- [ ] `update_plan` を更新した
- [ ] コミットは実施しない（禁止コマンドのため）

---

### S07 — 競合引数はエラーで拒否し、compose を呼ばない (必須)
- 対象: MUST（競合引数の拒否）
- 設計参照:
  - 対象IF: IF-003（競合引数ルール）
  - 対象テスト: `tests/sandbox_cli.test.sh::codex_rejects_conflicting_args_before_compose`
- このステップで「追加しないこと（スコープ固定）」:
  - 競合引数の “許容” や “上書き” はしない（2Aの決定に反する）

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に作業ステップを登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: `SANDBOX_CODEX_NO_TMUX=1`
- When: `sandbox codex ... -- --yolo`（または `--sandbox ...` 等）を実行する
- Then:
  - exit code != 0
  - stderr に “競合引数のため拒否” と `sandbox shell` の案内が出る
  - docker compose stub log に `CMD=` が出ない（compose を呼んでいない）
- 観測点: exit code / stderr / docker compose stub log
- 追加/更新するテスト: `tests/sandbox_cli.test.sh::codex_rejects_conflicting_args_before_compose`

#### Green（最小実装） (任意)
- 変更予定ファイル:
  - Modify: `host/sandbox`
  - Modify: `tests/sandbox_cli.test.sh`
- 実装方針:
  - `run_compose_up` より前に `CODEX_ARGS` を走査し、競合引数があれば即エラー終了する

#### ステップ末尾（省略しない） (必須)
- [ ] `bash tests/sandbox_cli.test.sh` を実行し成功した
- [ ] `.spec-dock/current/report.md` を更新した
- [ ] `update_plan` を更新した
- [ ] コミットは実施しない（禁止コマンドのため）

---

### S08 — 手動受け入れ（bootstrap→trust→yolo）を実施して report に残す (必須)
- 対象: AC-002（手動観測）, AC-001（手動観測）
- 設計参照:
  - `.spec-dock/current/discussions/manual-acceptance.md`
- このステップで「追加しないこと（スコープ固定）」:
  - 自動テストで skills を直接観測する仕組みの追加（proxy + 手動受け入れを正とする）

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に作業ステップを登録した

#### 期待する振る舞い（手動確認） (必須)
- Given: `.codex/skills/**/SKILL.md` が存在する repo
- When:
  1) 未Trust状態で `sandbox codex` を実行する（bootstrap になる）
  2) Codex UI で Trust を実行して終了する
  3) 再度 `sandbox codex` を実行する（YOLO になる）
- Then:
  - 2回目は repo-local skills が認識される
  - `~/.codex/config.toml` に `[projects.\"/srv/mount/<repo>\"] trust_level = \"trusted\"` が存在する
- 観測点: `.spec-dock/current/discussions/manual-acceptance.md` に記載

#### ステップ末尾（省略しない） (必須)
- [ ] 手動確認の結果（成功/失敗・観測点）を `.spec-dock/current/report.md` に記録した
- [ ] `update_plan` を更新した
- [ ] コミットは実施しない（禁止コマンドのため）

---

## 未確定事項（TBD） (必須)
- 該当なし

## 完了条件（Definition of Done） (必須)
- 対象AC/ECがすべて満たされ、proxy テスト（stub観測）で保証されている
- 手動受け入れ（S08）を実施し、観測結果が `.spec-dock/current/report.md` に残っている
- MUST NOT / OUT OF SCOPE を破っていない（外部ツールによる trust 付与 / config 機械編集をしていない）

## 省略/例外メモ (必須)
- コミットは実施しない（禁止コマンドのため）
