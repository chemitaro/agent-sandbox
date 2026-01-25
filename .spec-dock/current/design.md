---
種別: 設計書
機能ID: "SBX-CODEX-AUTO-BOOTSTRAP"
機能名: "sandbox codex: Trust状態に応じた自動Bootstrap/YOLO切替"
関連Issue: []
状態: "approved"
作成者: "Codex CLI (GPT-5.2)"
最終更新: "2026-01-26"
依存: ["requirement.md"]
---

# SBX-CODEX-AUTO-BOOTSTRAP sandbox codex: Trust状態に応じた自動Bootstrap/YOLO切替 — 設計（HOW）

## 目的・制約（要件から転記・圧縮） (必須)
- 目的:
  - `sandbox codex` を 1 本化し、Trust 未確立の初回でも skills が認識される導線を提供する。
  - Trust 済みの2回目以降は、最大権限（`approval_policy="never"`, `sandbox_mode="danger-full-access"`）で起動する。
- MUST:
  - Trust 判定 → bootstrap/yolo 自動選択
  - `codex resume` に `--cd <container_workdir>` を必ず付与
  - Git worktree を考慮（Trust判定は show-toplevel を使用）
  - 競合する Codex 引数が渡された場合はエラーにする（代替として `sandbox shell` を案内）
  - 非Gitは既定で YOLO + `--skip-git-repo-check`
- MUST NOT:
  - sandbox 側で `config.toml` の `projects` を機械編集して Trust を付与しない
  - `-c/--config` による `projects` “注入” を前提にしない
  - `sandbox shell` の挙動を変えない（素の `codex` は従来どおり）
- 非交渉制約:
  - テストは stub で観測し、実Docker/実Gitに依存しない（repo規約）
  - `sandbox codex` の引数仕様（`--mount-root/--workdir` と `--` 以降の passthrough）を維持する

---

## 既存実装/規約の調査結果（As-Is / 95%理解） (必須)
- 参照した規約/実装（根拠）:
  - `AGENTS.md`: Bash-first / testsはstub / help更新方針
  - `host/sandbox`:
    - `run_compose_exec_codex()`: コンテナ内で `codex resume` を起動
    - `split_codex_args()`: `sandbox codex -- [codex args...]` 分割
    - `compute_container_workdir()`: ホスト workdir → コンテナ `/srv/mount/...` 変換
    - `auto_detect_mount_root()`: git worktree 群の LCA を mount-root として推定
  - `docker-compose.yml`:
    - `.agent-home/.codex` が `/home/node/.codex` に bind mount される
  - 公式ドキュメント（リンクは discussions 側に集約予定）:
    - `codex resume` と `--cd/-C`、`--skip-git-repo-check`、`--config/-c`（`key=value`/JSON）など
    - `[projects."..."] trust_level = "trusted"` の形式
  - upstream issue:
    - “最大権限相当” のとき trust onboarding が抑止され、repo-local skills が見えない問題が既知
- 観測した現状（事実）:
  - `sandbox codex` は tmux セッションを作成し、最終的にコンテナ内で `codex resume` を起動する。
  - `sandbox codex -- ...` の `...` は `codex resume "$@"` にそのまま渡される。
  - `sandbox shell` は単に zsh を開く（Codex 起動は利用者が任意）。
  - Codex 設定は `/home/node/.codex` にあり、ホスト側は `.agent-home/.codex` が実体。
- 採用するパターン:
  - `host/sandbox` に関数追加＋既存の `codex` サブコマンド分岐のみを改修（差分最小化）。
  - 自動テストは `tests/sandbox_cli.test.sh` の docker compose stub log で “実行されるコマンド” を観測する。
- 採用しない/変更しない:
  - `sandbox shell` の挙動は変更しない（ユーザー要望）。
  - Trust の永続化（`projects` 追加）を sandbox が書かない（要件 MUST NOT）。

---

## 主要フロー（AC単位） (任意)
- Flow for AC-001（Trust済み → YOLO）:
  1) `ABS_MOUNT_ROOT/ABS_WORKDIR/container_workdir` を決定（既存）
  2) Git worktree root（show-toplevel）をホスト側で取得し、コンテナパスへ変換
  3) `.agent-home/.codex/config.toml` を読み、対象パスが `trust_level="trusted"` か判定
  4) true なら YOLO 引数を付与し、`codex resume --cd <container_workdir> ...` を起動
- Flow for AC-002（未Trust → bootstrap）:
  1) Trust 未確立を判定
  2) bootstrap 引数（= YOLO を付与しない）で `codex resume --cd ...` を起動
  3) stderr に「Trust→終了→再実行」案内を出す
- Flow for AC-003（非Git）:
  1) show-toplevel が取得できない
  2) `--skip-git-repo-check` を付与して YOLO で `codex resume --cd ...` を起動

---

## インターフェース契約（ここで固定） (任意)
### CLI（sandbox）
- `sandbox codex [options] -- [codex args...]`
  - options: `--mount-root <path>`, `--workdir <path>`（既存）
  - `--` 以降: Codex へ passthrough（ただし競合引数ルールは固定）
    - 競合引数が含まれる場合はエラーにし、`sandbox shell` の利用を案内する
    - 競合引数（検知対象）: `--yolo`, `--dangerously-bypass-approvals-and-sandbox`, `--sandbox/-s`, `--ask-for-approval/-a`, `--profile/-p`, `--config/-c`, `--cd/-C`

### 関数（host/sandbox 内部IF）
- IF-001: `compute_codex_mode(abs_mount_root, abs_workdir, container_workdir) -> mode`
  - `mode`: `bootstrap` or `yolo`
  - 付随情報として「trust_key（判定対象パス）」と「stderr警告」を出す実装にする
- IF-002: `is_codex_project_trusted(container_dir) -> bool`
  - `container_dir`: `/srv/mount/...` の絶対パス文字列
  - `true`: `trust_level="trusted"` が確認できる
  - `false`: それ以外
  - 許容する config 形式:
    - table形式:
      - `[projects."/srv/mount/repo"]`
      - `trust_level = "trusted"`
    - inline table形式:
      - `projects = { "/srv/mount/repo" = { trust_level = "trusted" }, ... }`
- IF-003: `build_codex_resume_args(mode, container_workdir, passthrough_args[]) -> argv[]`
  - 必ず `--cd <container_workdir>` を含める
  - `mode=yolo` の場合は YOLO相当の引数（`--sandbox danger-full-access`, `--ask-for-approval never`）を含める
  - 非Gitの場合は `--skip-git-repo-check` を含める
  - passthrough の競合引数は拒否（エラー）

---

## 詳細設計（引数組み立てと判定） (必須)

### 1) trust 判定対象（trust_key）の決定
- Input: `ABS_MOUNT_ROOT`, `ABS_WORKDIR`
- Algorithm（ホスト側）:
  1) `has_git_marker = find_git_marker("$ABS_WORKDIR")`（既存関数）
  2) `.git` が無い（`has_git_marker=false`）:
     - `git_state = non_git`
     - `trust_key = ""`
  3) `.git` がある（`has_git_marker=true`）:
     - `git_state = git_present`
     - `git -C "$ABS_WORKDIR" rev-parse --show-toplevel` を実行
       - 成功:
         - `git_state = git_ok`
         - `repo_root_host = resolve_path(<stdout>)`
         - `trust_key = compute_container_workdir "$ABS_MOUNT_ROOT" "$repo_root_host"`（例: `/srv/mount/<repo>`）
       - 失敗:
         - `git_state = git_error`（EC-002）
         - `trust_key = ""`（※ただし non_git とは区別して扱う）

### 2) codex config の参照パス
- `codex_config_host = "$SANDBOX_ROOT/.agent-home/.codex/config.toml"`
  - コンテナ側は `/home/node/.codex/config.toml`（bind mount）だが、`host/sandbox` はホスト側実体を読む。
  - 読み取りのみ（MUST NOT と整合）。

### 3) trust 判定（is_codex_project_trusted）
- `codex_config_host` が存在しない → `false`（EC-001）
- table形式:
  - `header` が `[projects."<trust_key>"]`（または single-quote 版）に一致するセクションを探す
  - セクション内に `trust_level = "trusted"` があれば `true`
- inline table形式:
  - 行全体から `"<trust_key>"` と `trust_level` と `trusted` が同一要素として現れるか、保守的に判定する
- 方針:
  - false positive を避ける（迷ったら `false` → bootstrap）

### 4) mode 判定（compute_codex_mode）
- `git_state = non_git`:
  - `mode = yolo`（`--skip-git-repo-check` を付与）
- `git_state = git_ok`:
  - `is_codex_project_trusted(trust_key)` が true → `mode=yolo`
  - false → `mode=bootstrap`（stderrに案内を出す）
- `git_state = git_error`:
  - `mode=bootstrap`（stderr に警告 + Trust案内を出す）

### 5) `codex resume` 引数組み立て（build_codex_resume_args）
- 常に付与:
  - `--cd <container_workdir>`（workdir固定）
- mode=yolo の場合に付与:
  - `--ask-for-approval never`
  - `--sandbox danger-full-access`
- `git_state=non_git` のとき:
  - `--skip-git-repo-check` を付与（Codexがgit必須の既定を回避するため）
- `git_state=git_error` のとき:
  - `--skip-git-repo-check` は付与しない（`.git` があるため）
- passthrough:
  - `sandbox codex -- [args...]` の `[args...]` を後ろに連結
  - ただし競合引数（`--yolo/--profile/--config/--sandbox/--ask-for-approval/--cd` 等）はエラー

### 6) bootstrap 時の stderr 案内（手動受け入れのため）
- bootstrap 起動に入る直前に、少なくとも以下を stderr に出す:
  - “このディレクトリは未Trustのため bootstrap で起動する”
  - “Codex UI で Trust を実行し、終了後に `sandbox codex` を再実行すると YOLO になる”

---

## 変更計画（ファイルパス単位） (必須)
- 追加（Add）:
  - `.spec-dock/current/discussions/manual-acceptance.md`: 手動受け入れ手順（成功/失敗の観測点つき）
  - `.spec-dock/current/discussions/questions-for-user.md`: 未確定事項の質問（選択肢＋推奨案）
- 変更（Modify）:
  - `host/sandbox`: `sandbox codex` の mode 選択＋引数組み立て＋ヘルプ文言更新
  - `tests/sandbox_cli.test.sh`: `sandbox codex` の引数組み立てを stub log で観測するテスト追加
- 参照（Read only / context）:
  - `docker-compose.yml`: `.agent-home/.codex` の mount
  - `tests/_helpers.sh`: stub の前提

---

## マッピング（要件 → 設計） (必須)
- AC-001 → IF-001/IF-002/IF-003, `host/sandbox`, `tests/sandbox_cli.test.sh`
- AC-002 → IF-001/IF-002/IF-003, `host/sandbox`（stderr案内）, `tests/sandbox_cli.test.sh`
- AC-003 → IF-001/IF-003, `host/sandbox`, `tests/sandbox_cli.test.sh`
- EC-001/EC-002/EC-003 → IF-001/IF-002, `host/sandbox`, `tests/sandbox_cli.test.sh`

---

## テスト戦略（最低限ここまで具体化） (任意)
- 追加/更新するテスト:
  - Bash: `tests/sandbox_cli.test.sh` に追加
- どのAC/ECをどのテストで保証するか（proxy）:
  - AC-001: Trust済み fixture → docker compose stub log に YOLO 引数が含まれる
  - AC-002: 未Trust fixture → YOLO 引数が含まれない + stderr に案内が出る
  - AC-003: 非Git fixture → `--skip-git-repo-check` が付く + YOLO 引数が付く
  - EC-001: config.toml 不在 → Gitなら bootstrap 扱い（案内あり）
  - EC-002: `.git` はあるが git rev-parse 失敗 → 警告 + fallback
- 実行コマンド:
  - `bash tests/sandbox_cli.test.sh`

---

## 未確定事項（TBD） (必須)
- 該当なし

---

## 省略/例外メモ (必須)
- UML 図は不要（単一 Bash コマンドの引数組み立てが中心のため）
