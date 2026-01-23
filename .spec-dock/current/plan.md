---
種別: 実装計画書
機能ID: "FEAT-005"
機能名: "動的マウント起動（任意ディレクトリをSandboxとして起動）"
関連Issue: ["https://github.com/chemitaro/agent-sandbox/issues/5"]
状態: "draft"
作成者: "Codex CLI"
最終更新: "2026-01-23"
依存: ["requirement.md", "design.md"]
---

# FEAT-005 動的マウント起動（任意ディレクトリをSandboxとして起動） — 実装計画（TDD: Red → Green → Refactor）

## この計画で満たす要件ID (必須)
- 対象AC:
  - AC-001, AC-002, AC-003, AC-004, AC-005, AC-007, AC-008, AC-009, AC-010, AC-011
  - AC-012, AC-013, AC-014, AC-015, AC-016, AC-017, AC-018, AC-019, AC-020, AC-021
- 対象EC: EC-001, EC-002, EC-003, EC-004, EC-005, EC-006
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
    - 例: `mktemp` 配下に `host/sandbox` を `tmp/host/sandbox` としてコピーして実行すると、その `tmp` 自体が SANDBOX_ROOT になる（`host/sandbox` は“自分のパス”から SANDBOX_ROOT を決めるため）
  - テストの重複を避けるため、共通ヘルパ（例: `tests/_helpers.sh`）を追加し、以下を提供する:
    - `make_fake_sandbox_root`（`docker-compose.yml` 等の疑似ルート生成。副作用なしテスト向けに `.env`/`.agent-home` を **作らない** モードも持つ）
    - `stub_docker` / `stub_docker_compose` / `stub_git`（PATH先頭へ差し込む）
    - `assert_stdout_eq` / `assert_stderr_contains` / `assert_exit_code`
    - `assert_no_files_created`（副作用なしの担保: `.env` / `.agent-home` が作られていないこと）

## ステップ一覧（観測可能な振る舞い） (必須)
- [ ] S01: `help/-h/--help` が最優先で表示できる
- [ ] S02: `sandbox name` が合成名を1行で出力する
- [ ] S03: パス決定（引数組み合わせ）と包含/変換ができる
- [ ] S04: git worktree 自動推定と “広すぎる” ガードが動く
- [ ] S14: prunable worktree を無視して自動推定できる
- [ ] S05: Docker/Compose 不在はエラーで停止できる（help/nameは動く）
- [ ] S06: `sandbox up` が build+up できる（stubで検証）
- [ ] S07: `sandbox shell` が up 後に exec -w で接続できる（stubで検証）
- [ ] S08: `sandbox build` が build のみ行う（stubで検証）
- [ ] S09: `sandbox stop/down` が冪等＆対象なしは真にno-op
- [ ] S10: `sandbox status` が状態/ID/パスを表示できる
- [ ] S11: `scripts/install-sandbox.sh` で symlink を配置できる
- [ ] S12: 旧フローの整理（README/Makefile/scripts）を反映する
- [ ] S13: DoD 実動の簡易integration検証を行う（手動）
- [ ] S15: timezone 検出失敗でも CLI が落ちない（best-effort）
- [ ] S16: Python 依存を撤去し、シェルのみで realpath を実現する
- [ ] S17: `sandbox codex` が tmux + codex resume を 1コマンドで起動できる

### 要件 ↔ ステップ対応表 (必須)
- AC-018 → S01
- AC-019 → S02
- AC-004, EC-004 → S02
- AC-002, AC-007, AC-012, EC-001, EC-002 → S03
- AC-001, AC-005, AC-013, EC-003 → S04
- AC-005 → S14
- EC-005 → S05
- AC-014, AC-011, AC-003 → S06
- AC-001, AC-002, AC-007, AC-012, AC-013 → S07
- AC-009, AC-010 → S13
- AC-017 → S08
- AC-015, AC-016 → S09
- AC-020 → S10
- AC-008 → S11
- OUT OF SCOPE 反映（旧フロー整理） → S12
- 非交渉制約（timezone best-effort） → S15
- 非交渉制約（Python 依存を持たない） → S16
- AC-021 → S17

---

## 実装ステップ（各ステップは“観測可能な振る舞い”を1つ） (必須)

### S01 — `help/-h/--help` が引数位置に関わらず最優先で表示できる (必須)
- 対象: AC-018
- 設計参照: IF-CLI-001（help例外）
- 対象テスト:
  - `tests/sandbox_cli.test.sh::help_top_level`
  - `tests/sandbox_cli.test.sh::help_subcommand`
  - `tests/sandbox_cli.test.sh::help_any_position`
  - `tests/sandbox_cli.test.sh::help_has_no_side_effects`
- スコープ固定:
  - help は副作用なし（`.env`/`.agent-home` 作成、Docker/Compose 呼び出しをしない）

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: `sandbox` コマンドがある
- When: 以下のいずれかを実行する
  - `sandbox --help` / `sandbox -h`（トップレベル）
  - `sandbox shell --help` / `sandbox shell -h`（サブコマンド）
  - `sandbox shell --workdir /nope --help`（`--help` が末尾/無効パス混在）
- Then:
  - パス検証をスキップしてヘルプを表示し、exit 0
  - `docker` / `git` を呼ばない（スタブで検知できる）
  - `.env` / `.agent-home` を作らない（`assert_no_files_created` で担保）

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
  - `tests/sandbox_name.test.sh::slug_normalization`
  - `tests/sandbox_name.test.sh::slug_fallback_when_empty`
  - `tests/sandbox_name.test.sh::container_name_length_limit`
  - `tests/sandbox_name.test.sh::sha_fallback_to_shasum`
- スコープ固定:
  - Docker を見に行かない（副作用なし、stdoutは1行のみ。ログはstderr）

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: `--mount-root`/`--workdir` を与えられる
- When: `sandbox name` を実行する
- Then:
  - `sandbox-<slug>-<hash12>` が stdout 1行だけ出る（完全一致で検証）
  - 追加ログが必要なら stderr に出る（stdout を汚さない）
  - slug は正規化され、空になった場合は `dir` に fallback する
  - 全体長は 63 文字目安に収まる

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
- 実装メモ（テスト容易性）:
  - `host/sandbox` は “source された場合に main を実行しない” 形にして、パス決定/変換の関数を直接テストできるようにする（CLI stdout に依存しない）。

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: `CALLER_PWD` と `--mount-root`/`--workdir` の組み合わせ（複数ケース）
- When: `tests/sandbox_paths.test.sh` で “パス決定/包含判定/コンテナ内パス変換” の純粋ロジックを直接検証する（`sandbox name` の stdout 1行契約に依存しない）
- Then: 最低限、以下が観測できる
  - `--mount-root` のみ → `workdir=mount-root` に補完され、`container_workdir=/srv/mount`
  - `--mount-root` + `--workdir`（配下） → `container_workdir=/srv/mount/<relative>`
  - `workdir ∉ mount-root` → EC-001 としてエラー
  - 境界判定で誤判定しない（`/a/b` と `/a/bb` のようなケース）
  - 空白を含むパスでも壊れない（EC-002）
  - 相対パスは `CALLER_PWD` 基準で正しく解決される
  - 末尾 `/` の有無などは正規化される

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

### S14 — prunable worktree を無視して自動推定できる (必須)
- 対象: AC-005
- 設計参照: 具体設計 3（worktree list のフィルタリング）
- 対象テスト: `tests/sandbox_git_detect.test.sh::prunable_worktree_is_skipped`

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: `git worktree list --porcelain` に **存在しない worktree パス** が含まれる
- When: 引数なし / `--workdir` のみで `mount-root` 自動推定を行う
- Then: 存在しないパスは無視され、残った候補から LCA が求まる（起動不能にならない）

#### ステップ末尾（省略しない） (必須)
- [ ] テスト成功
- [ ] `report.md` 更新
- [ ] `update_plan` 更新
- [ ] コミット（ユーザーが必要なら実施）

---

### S05 — Docker/Compose 不在はエラーで停止できる（help/nameは動く） (必須)
- 対象: EC-005
- 設計参照: 具体設計 7（Docker前提/エラー分類）
- 対象テスト:
  - `tests/sandbox_cli.test.sh::docker_cmd_missing_errors`
  - `tests/sandbox_cli.test.sh::docker_daemon_unreachable_errors`
  - `tests/sandbox_cli.test.sh::help_and_name_work_without_docker`

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に登録した

#### 期待する振る舞い（テストケース） (必須)
- Given:
  - ケースA: `docker` コマンドが存在しない
  - ケースB: `docker` は存在するが、デーモンへ疎通できない（例: `docker info` が exit 非0）
- When:
  - `sandbox status` / `sandbox up` / `sandbox shell` / `sandbox build` / `sandbox stop` / `sandbox down` を実行する
  - 併せて `sandbox help` / `sandbox name` を実行する
- Then:
  - Docker依存コマンドは exit 非0でエラー（not-found と誤判定しない）
  - `help/name` は Docker 不在でも成功（exit 0）し、stdout契約を守る

#### ステップ末尾（省略しない） (必須)
- [ ] テスト成功
- [ ] `report.md` 更新
- [ ] `update_plan` 更新
- [ ] コミット（ユーザーが必要なら実施）

---

### S06 — `sandbox up` が build+up できる（stubで検証） (必須)
- 対象: AC-014, AC-011, AC-003
- 設計参照: IF-CLI-001（up）/ 具体設計 0,0.1,7
- 対象テスト:
  - `tests/sandbox_cli.test.sh::up_runs_compose_from_sandbox_root`
  - `tests/sandbox_cli.test.sh::up_injects_required_env`
  - `tests/sandbox_cli.test.sh::up_creates_empty_env_if_missing`
  - `tests/sandbox_cli.test.sh::up_does_not_overwrite_existing_env`
  - `tests/sandbox_cli.test.sh::up_creates_agent_home_dirs`
  - `tests/sandbox_cli.test.sh::compose_command_selection_v2`
  - `tests/sandbox_cli.test.sh::compose_v1_is_rejected`
  - `tests/sandbox_cli.test.sh::tz_injection_rules`

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: 対象が確定できる
- When: `sandbox up` を実行する
- Then:
  - `docker compose up -d --build` 相当が **SANDBOX_ROOT 基準（cwd）** で呼ばれる
  - 注入envに以下が含まれる:
    - `CONTAINER_NAME`（表示用）
    - `COMPOSE_PROJECT_NAME`（Compose 制約に合う安全名）
    - `SOURCE_PATH`（= abs_mount_root）
    - `PRODUCT_WORK_DIR=/srv/mount`
    - `HOST_SANDBOX_PATH` / `HOST_USERNAME`
  - `.env`:
    - 無い場合は空ファイルを作成して継続する
    - 既にある場合は上書きしない（secrets保護）
  - `.agent-home`:
    - compose 実行前に必要ディレクトリが作成される
  - Compose コマンド選択:
    - `docker compose` を優先する
    - fallback の `docker-compose` は v2 のみ許可し、v1 は拒否する
  - TZ 注入:
    - `TZ` が未設定/空の場合は検出して注入する
    - `TZ` が非空で設定済みの場合は尊重する（上書きしない）

#### ステップ末尾（省略しない） (必須)
- [ ] テスト成功
- [ ] `report.md` 更新
- [ ] `update_plan` 更新
- [ ] コミット（ユーザーが必要なら実施）

---

### S07 — `sandbox shell` が up 後に exec -w で接続できる（stubで検証） (必須)
- 対象: AC-001, AC-002, AC-007, AC-012, AC-013
- 設計参照: IF-CLI-001（shell）/ 具体設計 5,7 / IF-ENV-001（DoD変数）
- 対象テスト:
  - `tests/sandbox_cli.test.sh::shell_exec_w`
  - `tests/sandbox_cli.test.sh::shell_injects_dod_env_vars`

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: 対象の `container_workdir` が決まる
- When: `sandbox`（=shell）を実行する
- Then:
  - up相当の後に `docker compose exec -w "$container_workdir"` が呼ばれる
  - `SOURCE_PATH` / `PRODUCT_WORK_DIR=/srv/mount` など DoD 関連の env が注入されている（実動の確認は S13）

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
- Then:
  - `docker compose build` のみが呼ばれる（起動/接続なし）
  - compose を呼ぶため、必要なら空 `.env` 作成や `.agent-home` 作成が行われる（ただし既存 `.env` は上書きしない）

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
- Given:
  - ケースA: 対象コンテナが存在しない（stub inspect not-found）
  - ケースB: 対象コンテナが存在する（stub inspect found）
- When: `sandbox stop` / `sandbox down` を実行する
- Then:
  - ケースA:
    - メッセージ+exit 0
    - `docker compose` を呼ばない
    - ホスト側ファイル生成/更新（空 `.env` 作成、`.agent-home` 作成など）もしない（真に no-op）
  - ケースB:
    - 事前準備（空 `.env` 作成・`.agent-home` 作成）が行われ得る
    - 対象の `CONTAINER_NAME/COMPOSE_PROJECT_NAME` を注入して `docker compose stop/down` が呼ばれる（他インスタンスを落とさない）

#### ステップ末尾（省略しない） (必須)
- [ ] テスト成功
- [ ] `report.md` 更新
- [ ] `update_plan` 更新
- [ ] コミット（ユーザーが必要なら実施）

---

### S10 — `sandbox status` が状態/ID/パスを表示できる (必須)
- 対象: AC-020
- 設計参照: IF-CLI-001（status）/ 具体設計 7（inspect）/ stdout契約（key: value）
- 対象テスト:
  - `tests/sandbox_cli.test.sh::status_output_keys`
  - `tests/sandbox_cli.test.sh::status_not_found_vs_docker_error`
  - `tests/sandbox_cli.test.sh::status_has_no_side_effects`

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に登録した

#### 期待する振る舞い（テストケース） (必須)
- Given:
  - ケースA: Docker疎通OKで対象が無い（stub）
  - ケースB: Docker疎通OKで対象がある（stub）
  - ケースC: Docker疎通不可（stub。EC-005）
- When: `sandbox status`
- Then:
  - ケースA:
    - `status=not-found` + `container_id=-` を stdout に出し、exit 0
  - ケースB:
    - `status=running|exited|created...` + `container_id=<12 chars>` を stdout に出し、exit 0
  - ケースC:
    - exit 非0でエラー（not-found と誤判定しない）
  - stdout は `key: value` 行で、**行順は問わず**「必要キーが各1回出ること」をパースして検証する
  - 副作用なし（`.env`/`.agent-home` を作らない）

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

#### 期待する振る舞い（テストケース） (必須)
- Given: `agent-sandbox` リポジトリがローカルに存在する
- When: `scripts/install-sandbox.sh` を実行する
- Then:
  - `/usr/local/bin/sandbox` が `host/sandbox` を指す symlink になる
  - 既存の `/usr/local/bin/sandbox` がある場合の挙動（上書き/エラー）は、スクリプトの出力で明確に分かる

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

#### 期待する振る舞い（テストケース） (必須)
- Given: 既存README/Makefile/scriptsが存在する
- When: 旧フロー整理の変更を適用する
- Then:
  - `README.md` が `sandbox` ベースの導線になっている（旧 `make start/shell` を前提にしない）
  - 旧 `make start/shell` が削除または非推奨として明示されている
  - 旧 `.env` 自動生成フロー（例: `scripts/generate-env.sh`）が削除または参照されない状態になる

#### ステップ末尾（省略しない） (必須)
- [ ] `report.md` 更新
- [ ] `update_plan` 更新
- [ ] コミット（ユーザーが必要なら実施）

---

### S13 — DoD 実動の簡易integration検証を行う（手動） (必須)
- 対象: AC-009, AC-010
- 設計参照:
  - `docker-compose.yml` の docker.sock mount / DoD env（`HOST_PRODUCT_PATH` / `PRODUCT_WORK_DIR`）
  - IF-ENV-001（`SOURCE_PATH=abs_mount_root`, `PRODUCT_WORK_DIR=/srv/mount`）
- 検証: 手動（実 docker / 実コンテナ）
- 手順（正）: `@.spec-dock/current/decision/S13_manual_steps.md`（この plan では観測点だけ固定し、詳細手順は重複させない）

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に登録した

#### 期待する振る舞い（テストケース） (必須)
- Given:
  - ホストで Docker が利用できる
  - `/Users/iwasawayuuta/workspace/product/taikyohiyou_project` が存在する（無い場合は同等の DoD 対象リポジトリで代替可。採用した代替パスは `report.md` に記録する）
- When:
  - `@.spec-dock/current/decision/S13_manual_steps.md` の手順に従って検証を実施する
- Then:
  - `docker version` が失敗しない（DoD が利用できる）
  - 検証スクリプトが期待通りの “コンテナ内パス→ホストパス変換” を行える（例: `taikyohiyou_project` では `.env.git` の `CURRENT_PROJECT_PATH` がホスト絶対パスになる）
  - 参考観測: `echo "$HOST_PRODUCT_PATH"` が `abs_mount_root`、`echo "$PRODUCT_WORK_DIR"` が `/srv/mount`

#### ステップ末尾（省略しない） (必須)
- [ ] 検証結果（実行コマンド/結果/観測点）を `report.md` に記録した
- [ ] `update_plan` 更新
- [ ] コミット（ユーザーが必要なら実施）

---

### S15 — timezone 検出失敗でも CLI が落ちない（best-effort） (必須)
- 対象: 非交渉制約（timezone 検出は失敗を許容）
- 設計参照: IF-ENV-001（TZ ルール）
- 対象テスト: `tests/sandbox_timezone.test.sh::detect_timezone_failures_fallback`

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: `readlink` / `systemsetup` / `timedatectl` が失敗する環境
- When: `detect_timezone` を呼び出す
- Then: 失敗で CLI が終了せず、`Asia/Tokyo` 等の既定値へフォールバックする

#### ステップ末尾（省略しない） (必須)
- [ ] テスト成功
- [ ] `report.md` 更新
- [ ] `update_plan` 更新
- [ ] コミット（ユーザーが必要なら実施）

---

### S16 — Python 依存を撤去し、シェルのみで realpath を実現する (必須)
- 対象: 非交渉制約（Python 依存なし）
- 設計参照: パス正規化（Python 非依存）
- 対象テスト: `tests/sandbox_realpath.test.sh::realpath_fallback_without_python`

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: `realpath` が無い（または失敗する）環境
- When: `realpath_safe` を symlink パスに対して呼び出す
- Then: Python に依存せず、実体パスが返る

#### ステップ末尾（省略しない） (必須)
- [ ] テスト成功
- [ ] `report.md` 更新
- [ ] `update_plan` 更新
- [ ] コミット（ユーザーが必要なら実施）

---

### S17 — `sandbox codex`（tmux セッション作成 + codex resume 起動）を追加する (必須)
- 対象: AC-021, EC-006
- 設計参照:
  - IF-CLI-001（`sandbox codex`）
  - 具体設計 7)（`sandbox codex` の tmux/内部モード/`--` ルール）
- 対象テスト（追加）:
  - `tests/sandbox_cli.test.sh::codex_outer_uses_tmux_and_session_name`
  - `tests/sandbox_cli.test.sh::codex_inner_runs_codex_resume_and_returns_to_zsh`
  - `tests/sandbox_cli.test.sh::codex_help_flag_after_double_dash_is_passed_to_codex`
  - `tests/sandbox_cli.test.sh::codex_errors_when_tmux_missing`

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に登録した

#### 期待する振る舞い（テストケース） (必須)
- Case A（外側: tmux を起動/再利用する）:
  - Given: ホストで `tmux` が利用できる（スタブでもよい）
  - When: `sandbox codex` を実行する
  - Then:
    - tmux セッション名が `basename(CALLER_PWD)` 由来で、`:` と `.` が `_` に置換され、末尾が `-codex-sandbox` になる
    - 同名セッションが既に存在する場合は再利用（attach/switch）し、増殖しない
- Case B（内側: tmux を作らずにコンテナ内で codex を起動する）:
  - Given: `SANDBOX_CODEX_NO_TMUX=1` が設定されている
  - When: `sandbox codex [common-options] -- [codex args...]` を実行する
  - Then:
    - `docker compose up -d --build` 相当が呼ばれる（shell と同様）
    - その後の `docker compose exec` が、コンテナ内で `codex resume` を起動する（`tmux-codex` は使わない）
    - `--` 以降の引数（`codex args`）が `codex resume` にそのまま渡される
    - `codex` 終了後にコンテナ内 zsh に戻れるように `exec /bin/zsh` が行われる
- Case C（`--` 以降の `--help` は sandbox が解釈しない）:
  - Given: `SANDBOX_CODEX_NO_TMUX=1` が設定されている
  - When: `sandbox codex -- --help` を実行する
  - Then:
    - sandbox の help を表示せず、`codex resume --help` として `docker compose exec` が呼ばれる
- Case D（tmux が無い場合はエラー）:
  - Given: `tmux` が見つからない
  - When: `sandbox codex` を実行する
  - Then: EC-006 に従い、エラーで終了する（exit 0 ではない）

#### 実装注意点（罠の先回り） (必須)
- `sandbox codex` 実装では `--` を **最優先で分割**し、sandbox 側の引数パース（共通引数/サブコマンド判定/help 判定）は `--` より前だけを対象にする
  - 現状の `host/sandbox` は `-h/--help` を「引数のどこにあっても」拾う実装のため、素直に `sandbox codex -- --help` を実装すると sandbox help と誤認し得る（要件違反）。必ず `--` で打ち切る。
  - `parse_common_args` も同様に `--` より後を見ない（codex args 側の `--workdir` 等を誤パースしない）
- S17 のスタブテストでは、コマンドログに `$*` を直列化して残すと（空白/クォートを含む codex args で）検証が壊れやすい
  - 方針: スタブは `printf '%q ' "$@"` を使ってログに残す（または同等の“引数境界が失われない”形式）
  - これにより `sandbox codex -- --help` だけでなく、将来 `sandbox codex -- --message "hello world"` のようなケースも壊れにくくなる

#### ステップ末尾（省略しない） (必須)
- [ ] テスト成功
- [ ] `report.md` 更新
- [ ] `update_plan` 更新
- [ ] コミット（※`git commit` 禁止のため、必要ならユーザーが実施）

## 未確定事項（TBD） (必須)
- 該当なし

## 完了条件（Definition of Done） (必須)
- 対象AC/ECがすべて満たされ、テストで保証されている
- MUST NOT / OUT OF SCOPE を破っていない（追加機能を入れていない）
- 品質ゲート（該当するテスト）が満たされている

## 省略/例外メモ (必須)
- `git add` / `git commit` / `git push` / `git merge` はこの環境では禁止のため、計画上は「ユーザーが必要なら実施」とする
