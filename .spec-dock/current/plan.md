---
種別: 実装計画書
機能ID: "FEAT-005"
機能名: "動的マウント起動（任意ディレクトリをSandboxとして起動）"
関連Issue: ["https://github.com/chemitaro/agent-sandbox/issues/5"]
状態: "draft"
作成者: "Codex CLI"
最終更新: "2026-01-22"
依存: ["requirement.md", "design.md"]
---

# FEAT-005 動的マウント起動（任意ディレクトリをSandboxとして起動） — 実装計画（TDD: Red → Green → Refactor）

## この計画で満たす要件ID (必須)
- 対象AC:
  - AC-001, AC-002, AC-003, AC-004, AC-005, AC-007, AC-008, AC-009, AC-010, AC-011
  - AC-012, AC-013, AC-014, AC-015, AC-016, AC-017, AC-018, AC-019, AC-020
- 対象EC: EC-001, EC-002, EC-003, EC-004, EC-005
- 非交渉制約（抜粋）:
  - `/srv/mount` 固定（動的モード）
  - `sandbox-<slug>-<hash12>`（hashは `abs_mount_root + "\\n" + abs_workdir` の sha256 先頭12文字）
  - `help/name/status` は副作用なし（ホスト側ファイル生成/更新なし）
  - `-h/--help` は引数のどこに出ても最優先（パス検証をスキップして exit 0）
  - `.env` は secrets として上書きしない（必要なら空 `.env` 作成は許容）
  - DoD の `HOST_PRODUCT_PATH` / `PRODUCT_WORK_DIR` の意味を壊さない

## テスト方針（計画レベル） (必須)
- Bash テストで “外部依存なし” を基本とする:
  - `docker` / `docker compose` / `git` は stub で置き換え、呼び出し内容（引数/環境変数/作業ディレクトリ）を検証する
  - 実ファイル（`.env` / `.agent-home`）を汚さないため、テストは `mktemp` で作る一時ディレクトリ上に最小の “疑似 SANDBOX_ROOT” を作って実行する

## ステップ一覧（観測可能な振る舞い） (必須)
- [ ] S01: `help/-h/--help` が最優先で表示できる
- [ ] S02: `sandbox name` が合成名を1行で出力する
- [ ] S03: パス決定（引数組み合わせ）と包含/変換ができる
- [ ] S04: git worktree 自動推定と “広すぎる” ガードが動く
- [ ] S05: Docker/Compose 不在はエラーで停止できる（help/nameは動く）
- [ ] S06: `sandbox up` が build+up できる（stubで検証）
- [ ] S07: `sandbox shell` が up 後に exec -w で接続できる（stubで検証）
- [ ] S08: `sandbox build` が build のみ行う（stubで検証）
- [ ] S09: `sandbox stop/down` が冪等＆対象なしは真にno-op
- [ ] S10: `sandbox status` が状態/ID/パスを表示できる
- [ ] S11: `scripts/install-sandbox.sh` で symlink を配置できる
- [ ] S12: 旧フローの整理（README/Makefile/scripts）を反映する

### 要件 ↔ ステップ対応表 (必須)
- AC-018 → S01
- AC-019 → S02
- AC-004, EC-004 → S02
- AC-002, AC-007, AC-012, EC-001, EC-002 → S03
- AC-001, AC-005, AC-013, EC-003 → S04
- EC-005 → S05
- AC-014, AC-011, AC-003 → S06
- AC-001, AC-002, AC-007, AC-012, AC-013, AC-009, AC-010 → S07
- AC-017 → S08
- AC-015, AC-016 → S09
- AC-020 → S10
- AC-008 → S11
- OUT OF SCOPE 反映（旧フロー整理） → S12

---

## 実装ステップ（各ステップは“観測可能な振る舞い”を1つ） (必須)

### S01 — `help/-h/--help` が引数位置に関わらず最優先で表示できる (必須)
- 対象: AC-018
- 設計参照: IF-CLI-001（help例外）
- 対象テスト: `tests/sandbox_cli.test.sh::help_any_position`
- スコープ固定:
  - help は副作用なし（`.env`/`.agent-home` 作成、Docker/Compose 呼び出しをしない）

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: `sandbox` コマンドがある
- When: `sandbox shell --workdir /nope --help`（`--help` が末尾）を実行する
- Then: パス検証をスキップしてヘルプを表示し、exit 0

#### ステップ末尾（省略しない） (必須)
- [ ] テスト成功
- [ ] `report.md` 更新
- [ ] `update_plan` 更新
- [ ] コミット（※`git commit` 禁止のため、必要ならユーザーが実施）

---

### S02 — `sandbox name` が合成名を stdout 1行で返す (必須)
- 対象: AC-019, AC-004, EC-004
- 設計参照: IF-CLI-001（name）/ 具体設計 2,6
- 対象テスト:
  - `tests/sandbox_cli.test.sh::name_one_line_stdout`
  - `tests/sandbox_name.test.sh::hash_deterministic_full_paths`
- スコープ固定:
  - Docker を見に行かない（副作用なし、stdoutは1行のみ。ログはstderr）

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: `--mount-root`/`--workdir` を与えられる
- When: `sandbox name` を実行する
- Then: `sandbox-<slug>-<hash12>` が stdout 1行だけ出る

#### ステップ末尾（省略しない） (必須)
- [ ] テスト成功
- [ ] `report.md` 更新
- [ ] `update_plan` 更新
- [ ] コミット（ユーザーが必要なら実施）

---

### S03 — パス決定（引数組み合わせ）と包含/変換ができる (必須)
- 対象: AC-002, AC-007, AC-012, EC-001, EC-002
- 設計参照: IF-CLI-001（引数共通）/ 具体設計 1,2,5
- 対象テスト: `tests/sandbox_paths.test.sh`

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: `--mount-root` のみ指定
- When: `sandbox name` を実行する
- Then: `workdir=mount-root` に補完され、`container_workdir=/srv/mount` になる

#### ステップ末尾（省略しない） (必須)
- [ ] テスト成功
- [ ] `report.md` 更新
- [ ] `update_plan` 更新
- [ ] コミット（ユーザーが必要なら実施）

---

### S04 — git worktree 自動推定と “広すぎる” ガードが動く (必須)
- 対象: AC-001, AC-005, AC-013, EC-003
- 設計参照: 具体設計 2,3,4
- 対象テスト: `tests/sandbox_git_detect.test.sh`

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: worktree を含む git 状況（stub `git`）
- When: 引数なし / `--workdir` のみで `mount-root` 自動推定
- Then: LCA が求まり、禁止パスや up-level 超過はエラーで拒否される

#### ステップ末尾（省略しない） (必須)
- [ ] テスト成功
- [ ] `report.md` 更新
- [ ] `update_plan` 更新
- [ ] コミット（ユーザーが必要なら実施）

---

### S05 — Docker/Compose 不在はエラーで停止できる（help/nameは動く） (必須)
- 対象: EC-005
- 設計参照: 具体設計 7（Docker前提/エラー分類）
- 対象テスト: `tests/sandbox_cli.test.sh::docker_unavailable`

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: `docker` が無い（stub）
- When: `sandbox status` を実行する
- Then: exit 非0でエラー（not-found と誤判定しない）

#### ステップ末尾（省略しない） (必須)
- [ ] テスト成功
- [ ] `report.md` 更新
- [ ] `update_plan` 更新
- [ ] コミット（ユーザーが必要なら実施）

---

### S06 — `sandbox up` が build+up できる（stubで検証） (必須)
- 対象: AC-014, AC-011, AC-003
- 設計参照: IF-CLI-001（up）/ 具体設計 0,0.1,7
- 対象テスト: `tests/sandbox_cli.test.sh::up_invocation`

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: 対象が確定できる
- When: `sandbox up` を実行する
- Then: `docker compose up -d --build` 相当が SANDBOX_ROOT 基準で呼ばれる（env注入含む）

#### ステップ末尾（省略しない） (必須)
- [ ] テスト成功
- [ ] `report.md` 更新
- [ ] `update_plan` 更新
- [ ] コミット（ユーザーが必要なら実施）

---

### S07 — `sandbox shell` が up 後に exec -w で接続できる（stubで検証） (必須)
- 対象: AC-001, AC-002, AC-007, AC-012, AC-013, AC-009, AC-010
- 設計参照: IF-CLI-001（shell）/ 具体設計 5,7 / IF-ENV-001（DoD変数）
- 対象テスト: `tests/sandbox_cli.test.sh::shell_exec_w`

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: 対象の `container_workdir` が決まる
- When: `sandbox`（=shell）を実行する
- Then: up相当の後に `docker compose exec -w "$container_workdir"` が呼ばれる

#### ステップ末尾（省略しない） (必須)
- [ ] テスト成功
- [ ] `report.md` 更新
- [ ] `update_plan` 更新
- [ ] コミット（ユーザーが必要なら実施）

---

### S08 — `sandbox build` が build のみ行う（stubで検証） (必須)
- 対象: AC-017
- 設計参照: IF-CLI-001（build）/ 具体設計 7
- 対象テスト: `tests/sandbox_cli.test.sh::build_only`

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: 対象が確定できる
- When: `sandbox build` を実行する
- Then: `docker compose build` のみが呼ばれる（起動/接続なし）

#### ステップ末尾（省略しない） (必須)
- [ ] テスト成功
- [ ] `report.md` 更新
- [ ] `update_plan` 更新
- [ ] コミット（ユーザーが必要なら実施）

---

### S09 — `sandbox stop/down` が冪等＆対象なしは真にno-op (必須)
- 対象: AC-015, AC-016
- 設計参照: 具体設計 0.1（条件付き事前準備）/ 具体設計 7（inspect→存在時のみcompose）
- 対象テスト: `tests/sandbox_cli.test.sh::stop_down_idempotent`

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: 対象コンテナが存在しない（stub inspect not-found）
- When: `sandbox down`
- Then: メッセージ+exit 0、composeを呼ばず、ファイル生成もしない

#### ステップ末尾（省略しない） (必須)
- [ ] テスト成功
- [ ] `report.md` 更新
- [ ] `update_plan` 更新
- [ ] コミット（ユーザーが必要なら実施）

---

### S10 — `sandbox status` が状態/ID/パスを表示できる (必須)
- 対象: AC-020
- 設計参照: IF-CLI-001（status）/ 具体設計 7（inspect）/ stdout契約（key: value）
- 対象テスト: `tests/sandbox_cli.test.sh::status_output`

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: Docker疎通OKで対象が無い（stub）
- When: `sandbox status`
- Then: `status=not-found` + `container_id=-` を stdout に出し、exit 0（ファイル生成なし）

#### ステップ末尾（省略しない） (必須)
- [ ] テスト成功
- [ ] `report.md` 更新
- [ ] `update_plan` 更新
- [ ] コミット（ユーザーが必要なら実施）

---

### S11 — `scripts/install-sandbox.sh` で symlink を配置できる (必須)
- 対象: AC-008
- 設計参照: 変更計画（installer）
- 検証: 手動（`/usr/local/bin` は権限が絡むため）

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に登録した

#### ステップ末尾（省略しない） (必須)
- [ ] `report.md` 更新
- [ ] `update_plan` 更新
- [ ] コミット（ユーザーが必要なら実施）

---

### S12 — 旧フローの整理（README/Makefile/scripts）を反映する (必須)
- 対象: OUT OF SCOPE（互換性なし）に沿った整理
- 設計参照: 変更計画（Makefile/README/CLAUDE/scripts）

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に登録した

#### ステップ末尾（省略しない） (必須)
- [ ] `report.md` 更新
- [ ] `update_plan` 更新
- [ ] コミット（ユーザーが必要なら実施）

---

## 未確定事項（TBD） (必須)
- 該当なし

## 完了条件（Definition of Done） (必須)
- 対象AC/ECがすべて満たされ、テストで保証されている
- MUST NOT / OUT OF SCOPE を破っていない（追加機能を入れていない）
- 品質ゲート（該当するテスト）が満たされている

## 省略/例外メモ (必須)
- `git add` / `git commit` / `git push` / `git merge` はこの環境では禁止のため、計画上は「ユーザーが必要なら実施」とする
