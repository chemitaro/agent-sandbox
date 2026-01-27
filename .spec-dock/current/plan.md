---
種別: 実装計画書
機能ID: "SBX-MOUNT-PROJECT-DIR"
機能名: "コンテナ内マウント先を /srv/mount/<project> 配下にしてプロジェクト名を保持"
関連Issue: []
状態: "draft"
作成者: "Codex CLI (GPT-5)"
最終更新: "2026-01-27"
依存: ["requirement.md", "design.md"]
---

# SBX-MOUNT-PROJECT-DIR コンテナ内マウント先を /srv/mount/<project> 配下にしてプロジェクト名を保持 — 実装計画（TDD: Red → Green → Refactor）

## この計画で満たす要件ID (必須)
- 対象AC: AC-001, AC-002, AC-003
- 対象EC: EC-001, EC-002
- 対象制約:
  - Bash のみ（`host/sandbox`）
  - コンテナ内 “マウント親” は `/srv/mount` を維持
  - `PRODUCT_NAME=mount` を維持
  - CLI 引数/サブコマンド仕様を互換性なく変更しない

## ステップ一覧（観測可能な振る舞い） (必須)
- [ ] S01: `compute_container_workdir()` が `/srv/mount/<project_dir>/...` を返す（`<project_dir>=basename(mount-root)`）
- [ ] S02: `sandbox up` / `sandbox shell` が `PRODUCT_WORK_DIR=/srv/mount/<project_dir>` を注入し、`exec -w` が新パスになる
- [ ] S03: `sandbox codex` が `--cd /srv/mount/<project_dir>/...` を使い、Trust 判定キーも新パスで動く
- [ ] S04: `<project_dir>` が unsafe の場合に自動変換し、stderr に警告を出す

### 要件 ↔ ステップ対応表 (必須)
- AC-001 → S01, S02, S03
- AC-002 → S01, S02, S03
- AC-003 → S02
- EC-001 → S04
- EC-002 → S01（既存のエラー挙動が維持されることを確認）
- 非交渉制約（Bashのみ / `/srv/mount` 維持 / `PRODUCT_NAME=mount`）→ S01, S02, S03, S04（全ステップで破らない）

---

## 実装ステップ（各ステップは“観測可能な振る舞い”を1つ） (必須)

### S01 — `compute_container_workdir()` が `/srv/mount/<project_dir>/...` を返す (必須)
- 対象: AC-001, AC-002, EC-002
- 設計参照:
  - 対象IF: IF-003（`@.spec-dock/current/design.md`）
  - 対象テスト:
    - `tests/sandbox_paths.test.sh::mount_root_only_sets_workdir`
    - `tests/sandbox_paths.test.sh::mount_root_and_workdir_maps_container_path`
    - `tests/sandbox_paths.test.sh::relative_paths_resolve_from_caller_pwd`
    - `tests/sandbox_paths.test.sh::paths_with_spaces_are_handled`
- このステップで「追加しないこと（スコープ固定）」:
  - `--mount-root` 自動推定ロジック（git worktree LCA）には手を入れない
  - `docker-compose.yml` / `Dockerfile` を変更しない

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に、このステップの作業ステップを登録した
- 登録例:
  - （調査）`host/sandbox::compute_container_workdir` の現状確認
  - （Red）`tests/sandbox_paths.test.sh` の期待値更新（失敗させる）
  - （Green）`host/sandbox` の変換を最小変更で通す
  - （Refactor）IF-001/IF-002/IF-003 の形へ寄せる（関数抽出）
  - （品質ゲート）`bash tests/sandbox_paths.test.sh`
  - （報告）`.spec-dock/current/report.md` 更新
  - （コミット）ユーザーが実施（エージェントは `git commit` 禁止）

#### 期待する振る舞い（テストケース） (必須)
- Given: `mount-root=/tmp/root`, `workdir=/tmp/root`
- When: `compute_container_workdir(abs_mount_root, abs_workdir)` を呼ぶ
- Then: `/srv/mount/root` を返す（`project_dir=basename(abs_mount_root)=root`）
- 観測点: 返り値（stdout）
- 追加/更新するテスト: `tests/sandbox_paths.test.sh::mount_root_only_sets_workdir`

#### Red（失敗するテストを先に書く） (任意)
- `tests/sandbox_paths.test.sh` の期待値を以下へ更新し、現状実装で失敗することを確認する:
  - `/srv/mount` → `/srv/mount/root`
  - `/srv/mount/sub/dir` → `/srv/mount/root/sub/dir`
  - `/srv/mount/sub` → `/srv/mount/root/sub`
  - `/srv/mount/sub dir` → `/srv/mount/root space/sub dir`

#### Green（最小実装） (任意)
- 変更予定ファイル:
  - Modify: `host/sandbox`
  - Modify: `tests/sandbox_paths.test.sh`
- 実装方針（最小）:
  - `project_dir="$(basename "$abs_mount_root")"` を導入し、返り値のベースを `/srv/mount/$project_dir` にする
  - `abs_mount_root == abs_workdir` の場合は `/srv/mount/$project_dir` を返す
  - 配下の場合は `/srv/mount/$project_dir/$rel` を返す

#### Refactor（振る舞い不変で整理） (任意)
- 目的: `@.spec-dock/current/design.md` の IF-001/IF-002/IF-003 へ近づける（後続ステップで使い回す）
- 変更対象: `host/sandbox`（関数抽出、重複削減）

#### ステップ末尾（省略しない） (必須)
- [ ] `bash tests/sandbox_paths.test.sh` を実行し、成功した
- [ ] `.spec-dock/current/report.md` に実行コマンド/結果/変更ファイルを記録した
- [ ] `update_plan` を更新し、このステップの作業ステップを完了にした
- [ ] コミットした（ユーザー。エージェントは `git commit` 禁止のため）

---

### S02 — `sandbox up` / `sandbox shell` が `PRODUCT_WORK_DIR=/srv/mount/<project_dir>` を注入し、`exec -w` が新パスになる (必須)
- 対象: AC-001, AC-002, AC-003
- 設計参照:
  - 対象IF: IF-ENV-001, IF-003（`@.spec-dock/current/design.md`）
  - 対象テスト:
    - `tests/sandbox_cli.test.sh::up_injects_required_env`
    - `tests/sandbox_cli.test.sh::shell_exec_w`
    - `tests/sandbox_cli.test.sh::shell_injects_dod_env_vars`
- このステップで「追加しないこと（スコープ固定）」:
  - `docker-compose.yml` の書式（long syntax 移行等）はこの段階ではやらない（必要になったら別ステップで提案）
  - `PRODUCT_NAME` は固定のまま（`mount`）

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に、このステップの作業ステップを登録した
- 登録例:
  - （調査）`host/sandbox::prepare_compose_env` の注入値確認
  - （Red）`tests/sandbox_cli.test.sh` の期待値更新（失敗させる）
  - （Green）`PRODUCT_WORK_DIR` を `/srv/mount/<project_dir>` へ変更
  - （Refactor）`compute_container_mount_root` を使って一貫させる
  - （品質ゲート）`bash tests/sandbox_cli.test.sh`
  - （報告）`.spec-dock/current/report.md` 更新
  - （コミット）ユーザーが実施（エージェントは `git commit` 禁止）

#### 期待する振る舞い（テストケース） (必須)
- Given: `mount-root=/tmp/project`, `workdir=/tmp/project/subdir`
- When: `sandbox shell --mount-root ... --workdir ...` を実行する（stub）
- Then:
  - `PRODUCT_WORK_DIR=/srv/mount/project` が注入される
  - `docker compose exec -w /srv/mount/project/subdir ...` が呼ばれる
- 観測点: compose stub ログ（`tests/sandbox_cli.test.sh`）
- 追加/更新するテスト:
  - `tests/sandbox_cli.test.sh::up_injects_required_env`
  - `tests/sandbox_cli.test.sh::shell_exec_w`

#### Red（失敗するテストを先に書く） (任意)
- `tests/sandbox_cli.test.sh` の以下期待値を更新して失敗させる:
  - `PRODUCT_WORK_DIR=/srv/mount` → `PRODUCT_WORK_DIR=/srv/mount/project`
  - `exec -w /srv/mount/subdir` → `exec -w /srv/mount/project/subdir`
  - `exec -w /srv/mount` → `exec -w /srv/mount/project`

#### Green（最小実装） (任意)
- 変更予定ファイル:
  - Modify: `host/sandbox`
  - Modify: `tests/sandbox_cli.test.sh`
- 実装方針（最小）:
  - `prepare_compose_env()` の `PRODUCT_WORK_DIR` を `compute_container_mount_root(abs_mount_root)` に置き換える
  - `shell` の `exec -w` は `compute_container_workdir()` の結果を使う（S01 の結果が前提）

#### Refactor（振る舞い不変で整理） (任意)
- 目的: `/srv/mount/<project_dir>` の生成を 1 箇所に集約し、ログ/テストの更新漏れを減らす
- 変更対象: `host/sandbox`

#### ステップ末尾（省略しない） (必須)
- [ ] `bash tests/sandbox_cli.test.sh` を実行し、成功した
- [ ] `.spec-dock/current/report.md` に実行コマンド/結果/変更ファイルを記録した
- [ ] `update_plan` を更新し、このステップの作業ステップを完了にした
- [ ] コミットした（ユーザー。エージェントは `git commit` 禁止のため）

---

### S03 — `sandbox codex` が `--cd /srv/mount/<project_dir>/...` を使い、Trust 判定キーも新パスで動く (必須)
- 対象: AC-001, AC-002
- 設計参照:
  - 対象IF: IF-003, IF-ENV-001（`@.spec-dock/current/design.md`）
  - 対象テスト:
    - `tests/sandbox_cli.test.sh::codex_inner_adds_cd_to_resume`
    - `tests/sandbox_cli.test.sh::codex_inner_runs_codex_resume_and_returns_to_zsh`
    - `tests/sandbox_cli.test.sh::codex_inner_runs_yolo_when_trusted`
    - `tests/sandbox_cli.test.sh::codex_inner_trusts_git_common_dir_root`
    - `tests/sandbox_cli.test.sh::codex_inner_runs_bootstrap_when_untrusted_and_prints_hint`
- このステップで「追加しないこと（スコープ固定）」:
  - Trust 判定のロジック自体（bootstrap/YOLO切替の仕様）を変えない
  - `.agent-home/.codex/config.toml` のフォーマット前提は変えない

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に、このステップの作業ステップを登録した
- 登録例:
  - （調査）codex 系テストが期待している `/srv/mount/...` を棚卸し
  - （Red）期待値と config.toml stub を新パスへ更新して失敗させる
  - （Green）必要なら `host/sandbox` の trust_key 算出（`compute_container_workdir`）を微調整
  - （品質ゲート）`bash tests/sandbox_cli.test.sh`
  - （報告）`.spec-dock/current/report.md` 更新
  - （コミット）ユーザーが実施（エージェントは `git commit` 禁止）

#### 期待する振る舞い（テストケース） (必須)
- Given: `mount-root=/tmp/project`, `workdir=/tmp/project/subdir`
- When: `sandbox codex --mount-root ... --workdir ...` を実行する（stub）
- Then: `codex resume` に `--cd /srv/mount/project/subdir` が付与される
- 観測点: compose stub ログ（`tests/sandbox_cli.test.sh`）
- 追加/更新するテスト: `tests/sandbox_cli.test.sh::codex_inner_adds_cd_to_resume`

#### Red（失敗するテストを先に書く） (任意)
- codex テスト内の `/srv/mount/...` 期待値を `/srv/mount/<project_dir>/...` へ更新する
- Trust ありケースの `config.toml` も新しい trust_key に合わせて更新する
  - 例（既存テストの mount-root が `mount-root` の場合）:
    - 旧: `[projects."/srv/mount/repo"]`
    - 新: `[projects."/srv/mount/mount-root/repo"]`

#### Green（最小実装） (任意)
- 変更予定ファイル:
  - Modify: `tests/sandbox_cli.test.sh`
  - （必要なら）Modify: `host/sandbox`
- 実装方針（最小）:
  - まずはテスト更新で整合させ、`compute_container_workdir()` が trust_key と `--cd` の両方で一貫して使われていることを確認する

#### ステップ末尾（省略しない） (必須)
- [ ] `bash tests/sandbox_cli.test.sh` を実行し、成功した
- [ ] `.spec-dock/current/report.md` に実行コマンド/結果/変更ファイルを記録した
- [ ] `update_plan` を更新し、このステップの作業ステップを完了にした
- [ ] コミットした（ユーザー。エージェントは `git commit` 禁止のため）

---

### S04 — `<project_dir>` が unsafe の場合に自動変換し、stderr に警告を出す (必須)
- 対象: EC-001
- 設計参照:
  - 対象IF: IF-001（`@.spec-dock/current/design.md`）
  - 対象テスト（追加）:
    - `tests/sandbox_cli.test.sh::<新規テスト>` または `tests/sandbox_paths.test.sh::<新規テスト>`
- このステップで「追加しないこと（スコープ固定）」:
  - “unsafe の網羅” を欲張らない（まずは `:` と制御文字に限定。設計どおり）
  - stdout の契約を汚さない（警告は stderr）

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に、このステップの作業ステップを登録した
- 登録例:
  - （調査）compose の `host:container` 記法と `:` の衝突点を再確認
  - （Red）unsafe basename（例: `my:proj`）のテストを追加し失敗させる
  - （Green）`:`→`_`、制御文字削除、空なら `dir` へフォールバック
  - （Refactor）警告の重複出力を避ける（同一 mount-root で 1 回に抑える）
  - （品質ゲート）該当テスト + 既存テスト
  - （報告）`.spec-dock/current/report.md` 更新
  - （コミット）ユーザーが実施（エージェントは `git commit` 禁止）

#### 期待する振る舞い（テストケース） (必須)
- Given: `mount-root=/tmp/my:proj`, `workdir=/tmp/my:proj`
- When: `sandbox up` などで `PRODUCT_WORK_DIR` を注入する
- Then:
  - `PRODUCT_WORK_DIR=/srv/mount/my_proj`（例）が注入される
  - stderr に “unsafe なので変換した” 警告が出る
- 観測点: stub ログ + `RUN_STDERR`

#### Red（失敗するテストを先に書く） (任意)
- `mount-root` の basename に `:` を含むケースを作り、
  - 変換されない（=`:` が残る）こと
  - stderr 警告が無いこと
  を “現状の失敗” として観測する

#### Green（最小実装） (任意)
- 変更予定ファイル:
  - Modify: `host/sandbox`
  - Add/Modify: `tests/sandbox_cli.test.sh`（または `tests/sandbox_paths.test.sh`）
- 実装方針（最小）:
  - `compute_project_dir()` で unsafe 判定/変換を実施し、変換時に stderr 警告を出す

#### Refactor（振る舞い不変で整理） (任意)
- 目的: 警告が `up` と `shell` と `codex` で多重に出ないようにする（ノイズ抑制）

#### ステップ末尾（省略しない） (必須)
- [ ] 追加したテスト + `bash tests/sandbox_cli.test.sh` / `bash tests/sandbox_paths.test.sh` を実行し、成功した
- [ ] `.spec-dock/current/report.md` に実行コマンド/結果/変更ファイルを記録した
- [ ] `update_plan` を更新し、このステップの作業ステップを完了にした
- [ ] コミットした（ユーザー。エージェントは `git commit` 禁止のため）

---

## 未確定事項（TBD） (必須)
- 該当なし

## 完了条件（Definition of Done） (必須)
- AC-001/002/003 と EC-001/002 がすべて満たされ、テストで保証されている
- MUST NOT / OUT OF SCOPE を破っていない（追加機能を入れていない）
- `bash tests/sandbox_paths.test.sh` と `bash tests/sandbox_cli.test.sh` が成功する

## 省略/例外メモ (必須)
- 本リポジトリ運用（`AGENTS.md`）により、エージェントは `git add` / `git commit` を実行しない。各ステップのコミットはユーザーが実施する。

