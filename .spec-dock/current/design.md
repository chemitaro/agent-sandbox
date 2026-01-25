---
種別: 設計書
機能ID: "FEAT-SANDBOX-CODEX-RUNTIME-TRUST-001"
機能名: "sandbox codex の runtime trust 注入（最大権限デフォルトと skills 有効化）"
関連Issue: []
状態: "draft"
作成者: "Codex CLI"
最終更新: "2026-01-25"
依存: ["requirement.md"]
---

# FEAT-SANDBOX-CODEX-RUNTIME-TRUST-001 sandbox codex の runtime trust 注入（最大権限デフォルトと skills 有効化） — 設計（HOW）

## 目的・制約（要件から転記・圧縮） (必須)
- 目的:
  - `sandbox codex` 実行時に、最大権限（`-a never -s danger-full-access`）をデフォルト付与しつつ、repo-scope skills を確実に有効化する。
  - 永続設定（`~/.codex/config.toml`）を汚さず、Codex 標準の runtime override（`-c/--config`）で trust を注入する。
- MUST:
  - `host/sandbox` の `codex` サブコマンドで `codex resume` の引数を組み立てる（`-a/-s/-C/-c` の付与と重複回避）。
  - git repo / worktree / 非 git の各ケースで trust 注入の判断を行う。
  - git 判定/取得に失敗しても `sandbox codex` 自体は起動できる（fatal にしない）。
- MUST NOT:
  - `.agent-home/.codex/config.toml` や `~/.codex/config.toml` を作成/編集しない。
  - 実 Docker/Git を前提にした自動テストを追加しない（既存 stub 方針に従う）。
- 非交渉制約:
  - Bash-first（`set -euo pipefail`、明示 quoting、`local`）を守る。
  - 禁止 Git コマンド（`git add/commit/push/merge`）は実行しない（本環境制約）。
- 前提:
  - `sandbox codex` は外部で隔離された環境（Docker コンテナ）であり、最大権限付与を許容する運用前提。

---

## 既存実装/規約の調査結果（As-Is / 95%理解） (必須)
- 参照した規約/実装（根拠）:
  - `AGENTS.md`: 会話は日本語 / Bash-first / テストは stub / 禁止 Git コマンド
  - `host/sandbox`:
    - `run_compose_exec_codex`: `codex resume` の実行（現状は引数加工なし）
    - `split_codex_args`: `sandbox codex [options] -- [codex args...]` の分割
    - `auto_detect_mount_root`: `git rev-parse --show-toplevel` と `git worktree list --porcelain` を利用
    - `compute_container_workdir`: host パスを `/srv/mount/...` へ写像
  - `tests/sandbox_cli.test.sh`: docker compose / git stub を使って起動コマンドを観測する
  - Codex CLI OSS（openai/codex）:
    - `-c/--config` は `key=value`、`key` は `.` 区切りでエスケープなし: `codex-rs/common/src/config_override.rs`
    - `-s/--sandbox` は `danger-full-access` 等: `codex-rs/common/src/sandbox_mode_cli_arg.rs`
    - `-a/--ask-for-approval` は `never` 等: `codex-rs/common/src/approval_mode_cli_arg.rs`
    - `-C/--cd` が作業ディレクトリ指定: `codex-rs/tui/src/cli.rs`
- 観測した現状（事実）:
  - `sandbox codex` は `docker compose exec -w <container_workdir> ... codex resume ...` を実行するが、デフォルト引数（`-a/-s/-C`）や trust 注入（`-c projects=...`）を行っていない。
  - その結果、Codex 側で trust が成立しない条件では、repo-scope skills が無効化され得る。
- 採用するパターン:
  - 永続 config 編集ではなく、`codex` の `-c` runtime override を使用する。
  - 自動テストは「起動コマンド（compose stub ログ）を proxy 観測」とし、skills の直接観測は手動受け入れで担保する。

## 主要フロー（テキスト：AC単位で短く） (任意)
- Flow for AC-001（git repo）:
  1) `host/sandbox` が mount-root / workdir を決定し、コンテナ側 workdir を `/srv/mount/...` に確定する
  2) `sandbox codex` がユーザー args を解析し、デフォルト引数（`-a/-s/-C`）と runtime trust（`-c projects=...`）を組み立てる
  3) `codex resume <assembled args>` を起動する
- Flow for AC-003（非 git）:
  1) git 判定に失敗した場合、effective `--cd` ディレクトリを trust として注入する（Q-002=B）
  2) `codex resume` は起動し、必要なら警告を出す

## データ・バリデーション（必要最小限） (任意)
- 該当なし（CLI 引数の組み立てのみ）

## 判断材料/トレードオフ（Decision / Trade-offs） (任意)
- 決定事項（requirement.md の Q の回答）:
  - Q-001: **C**（worktree root + root git project for trust の両方を `projects` に注入）
  - Q-002: **B**（非 git でも effective `--cd` を trust として注入）
  - Q-003: **A**（自動 trust 注入の opt-out は追加しない）
  - Q-004: **No**（`sandbox shell` のプレーン codex は対象外）

## インターフェース契約（ここで固定） (任意)
### API（ある場合）
- 該当なし

### 関数・クラス境界（重要なものだけ）
- IF-001: `host/sandbox`（bash）: `build_codex_resume_args() -> array<string>`
  - Input:
    - `ABS_MOUNT_ROOT`（host 絶対パス）
    - `ABS_WORKDIR`（host 絶対パス）
    - `CODEX_ARGS[]`（ユーザーが `--` 以降で渡した codex args）
  - Output:
    - `FINAL_CODEX_ARGS[]`（`codex resume` に渡す最終引数列）
  - Errors/Exceptions:
    - git 判定に失敗しても fatal にしない（stderr 警告 + effective dir を trust として注入）
    - trust 対象が mount-root の外に解決される場合は、その trust だけ注入しない（安全側）。`codex resume` 自体は起動する。
- IF-002: `host/sandbox`（bash）: `compute_trust_dirs() -> list<host_abs_path>`
  - Input: `effective_host_dir`（`ABS_WORKDIR` とユーザー指定 `-C/--cd` から決める）
  - Output:
    - git の場合:
      - `git -C "$effective_host_dir" rev-parse --show-toplevel`（worktree root）
      - `git -C "$effective_host_dir" rev-parse --git-common-dir` の親（root git project for trust）
      - 上記 2 件を重複排除した host 絶対パス
    - 非 git の場合:
      - `effective_host_dir` の 1 件（Q-002=B）
- IF-003: `host/sandbox`（bash）: `to_container_path(abs_mount_root, host_abs_path) -> /srv/mount/...`

### 引数の組み立てルール（固定） (任意)
- 付与するデフォルト（ユーザー未指定の場合のみ）:
  - `-a never`（`--ask-for-approval never`）
  - `-s danger-full-access`（`--sandbox danger-full-access`）
  - `-C .`（`--cd .`）
- 重複回避（ユーザー指定の検知）:
  - `-a <mode>`, `-a<mode>`, `--ask-for-approval <mode>`, `--ask-for-approval=<mode>`
  - `-s <mode>`, `-s<mode>`, `--sandbox <mode>`, `--sandbox=<mode>`
  - `-C <dir>`, `-C<dir>`, `--cd <dir>`, `--cd=<dir>`
- `-c/--config` の注入方式:
  - dotted path（例: `projects.\"/srv/mount/repo\".trust_level=...`）は **使用しない**
    - 理由: `-c` の key は `.` 区切りでエスケープできず、パスに `.` が含まれると破綻するため（Codex OSS 実装）。
  - 代わりに、`projects` を inline table で注入する:
    - 例: `-c 'projects={\"/srv/mount/repo\"={trust_level=\"trusted\"}}'`
  - trust 対象が複数ある場合は、**1 回の `-c projects=...` でまとめて注入**する（重複は除外）。
- 引数の並び順:
  - `FINAL_CODEX_ARGS = INJECTED_ARGS + USER_ARGS`
    - 目的: prompt（位置引数）の後ろに option をぶら下げてパースを壊す事故を避ける / ユーザーが明示指定した場合は後勝ちで上書きできる

## 変更計画（ファイルパス単位） (必須)
- 追加（Add）:
  - `.spec-dock/current/discussions/questions-for-user.md`: 未確定事項（Q-001〜）の確認用レポート
- 変更（Modify）:
  - `host/sandbox`: `sandbox codex` の `codex resume` 引数組み立て（`-a/-s/-C/-c`）と trust dir 計算を追加
  - `tests/sandbox_cli.test.sh`: 永続 config 編集前提のテストを削除/置換し、新しい proxy 観測テストを追加
- 削除（Delete）:
  - なし（必要ならテストケース単位で削除）
- 移動/リネーム（Move/Rename）:
  - なし
- 参照（Read only / context）:
  - `host/sandbox`: mount-root/workdir 決定と compose 実行
  - `tests/_helpers.sh`: stub 共通

## マッピング（要件 → 設計） (必須)
- AC-001 → IF-001/002/003, `host/sandbox`, `tests/sandbox_cli.test.sh`（proxy）
- AC-002 → IF-001/002/003, `host/sandbox` + 手動受け入れ（report に記録）
- AC-003 → IF-002（非 git 判定）, `host/sandbox`, `tests/sandbox_cli.test.sh`
- AC-004 → IF-001（ユーザー指定検知/重複回避）, `host/sandbox`, `tests/sandbox_cli.test.sh`
- EC-001/002 → IF-002（git 失敗/範囲外パス）, `host/sandbox`
- 非交渉制約（永続 config 編集禁止） → `host/sandbox` が config ファイルに触れない設計 + テストで担保

## テスト戦略（最低限ここまで具体化） (任意)
- 自動テスト（proxy）:
  - `tests/sandbox_cli.test.sh` で compose stub ログを検査し、`codex resume` の引数（`-a/-s/-C/-c`）が期待通りであることを保証する
  - `.agent-home/.codex/config.toml` が作成/更新されないことを assert する（永続 config 編集禁止の担保）
- 手動受け入れ（AC-002）:
  - `.spec-dock/current/report.md` に手順/コマンド/観測結果（skills が認識された）を記録する
- 実行コマンド:
  - `bash tests/sandbox_cli.test.sh`

## リスク/懸念（Risks） (任意)
- R-001: `-c` の dotted path 方式はパスに `.` が含まれると壊れる
  - 対応: `-c 'projects={\"/srv/mount/...\"={trust_level=\"trusted\"}}'` の inline table 方式を採用する
- R-002: 自動 trust 注入により意図しない `.codex` が有効化される可能性
  - 対応: Q-002=B の決定により、非 git でも trust 注入は行う（＝爆発半径は増える）。本ツールの前提（隔離環境で最大権限）として受容し、必要なら将来 opt-out を追加する（別機能）。

## 未確定事項（TBD） (必須)
- 該当なし（Q-001〜Q-004 は 2026-01-25 に解消済み）

---

## ディレクトリ/ファイル構成図（変更点の見取り図） (任意)
```text
<repo-root>/
├── host/
│   └── sandbox                       # Modify
├── tests/
│   └── sandbox_cli.test.sh           # Modify
└── .spec-dock/
    └── current/
        ├── requirement.md            # Modify（Q 確定後）
        ├── design.md                 # Modify
        └── discussions/
            └── questions-for-user.md # Add
```

## UML図（PlantUML） (任意)
- 該当なし（CLI 引数の組み立てであり、UML による整理の価値が薄い）

## 省略/例外メモ (必須)
- 該当なし
