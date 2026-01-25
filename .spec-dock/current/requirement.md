---
種別: 要件定義書
機能ID: "FEAT-SANDBOX-CODEX-RUNTIME-TRUST-001"
機能名: "sandbox codex の runtime trust 注入（最大権限デフォルトと skills 有効化）"
関連Issue: []
状態: "draft"
作成者: "Codex CLI"
最終更新: "2026-01-25"
---

# FEAT-SANDBOX-CODEX-RUNTIME-TRUST-001 sandbox codex の runtime trust 注入（最大権限デフォルトと skills 有効化） — 要件定義（WHAT / WHY）

## 目的（ユーザーに見える成果 / To-Be） (必須)
- `sandbox codex` 実行時に、**設定ファイルを汚さず**、かつ **常に最大権限（approval なし + sandbox full access 相当）**で Codex を起動できる。
- その際、対象ディレクトリが `.codex/skills` を持つ場合でも、Codex 側の trust 未登録で skills が無効化される問題を回避し、**skills が安定して認識される**。

## 背景・現状（As-Is / 調査メモ） (必須)
- 現状の挙動（事実）:
  - Codex CLI は、未 trust のディレクトリ配下にある project config folders（例: `.codex/skills`）を無効化し得る。
  - さらに `approval_policy` / `sandbox_mode` を明示設定すると、Codex の trust 画面（初回の「このディレクトリを信頼しますか？」）が表示されず、trust が永続設定に登録されないケースがある。
- 現状の課題（困っていること）:
  - コンテナ内で `sandbox codex` を使うと「skills が認識されない」ことがあり、原因が分かりにくい。
  - 回避策として `~/.codex/config.toml` の `[projects]` を外部ツールで機械編集すると、仕様変更に弱く、設定の肥大化/重複や保守性の問題がある。
- 目指す方針（今回の前提）:
  - `sandbox codex` は「外部で隔離された環境（Docker コンテナ）」として運用し、Codex に **最大権限**を与える（本ツールの目的）。
  - trust は永続ファイルを編集せず、**Codex 標準の runtime override（`-c/--config`）**でその場限りの trust を注入して解決する。
- 観測点（どこを見て確認するか）:
  - 自動テスト（proxy）: `host/sandbox` が `codex resume` に付与する引数（`-a/-s/-C/-c`）を compose stub ログで観測する。
  - 手動確認（受け入れ）: git repo かつ `.codex/skills` がある場所で `sandbox codex` を起動し、Codex が skills を認識することを確認する。
- 情報源（ヒアリング/調査の根拠）:
  - Codex CLI OSS（openai/codex）:
    - `-c/--config` は dotted path で上書きするが、`.` 区切りはエスケープされない（`codex-rs/common/src/config_override.rs`）。
    - `-s/--sandbox` は `danger-full-access` などの ValueEnum（`codex-rs/common/src/sandbox_mode_cli_arg.rs`）。
    - `-a/--ask-for-approval` は `never` などの ValueEnum（`codex-rs/common/src/approval_mode_cli_arg.rs`）。
    - `-C/--cd` が作業ディレクトリ指定（`codex-rs/tui/src/cli.rs`）。
  - 本リポジトリ:
    - `host/sandbox` が `codex resume` を起動している（`run_compose_exec_codex`）。
    - 既存テストは docker/git を stub 化して観測している（`tests/sandbox_cli.test.sh`）。

## 対象ユーザー / 利用シナリオ (任意)
- 主な利用者（ロール）:
  - `sandbox` CLI の利用者（開発者、レビュアー、AI エージェント運用者）
- 代表的なシナリオ:
  - git repo（worktree 含む）で `sandbox codex` を実行し、repo-scope skills（`.codex/skills/*/SKILL.md`）を使って作業する。
  - git ではない作業ディレクトリでも `sandbox codex` を実行し、必要ならそのディレクトリの `.codex` を有効化して作業する（運用要件）。

## スコープ（暴走防止のガードレール） (必須)
- MUST（必ずやる）:
  - `sandbox codex` はデフォルトで Codex に最大権限を与える:
    - `--ask-for-approval never`
    - `--sandbox danger-full-access`
  - `sandbox codex` はデフォルトで作業ディレクトリを固定する:
    - `codex resume --cd .`（ユーザーが `-C/--cd` を指定した場合は尊重する）
  - `sandbox codex` は Codex の runtime override（`-c/--config`）で、**その実行に限って** trust を注入する:
    - git repo の場合: git から trust 対象ディレクトリを特定し、`projects={ "<trust_dir_1>"={trust_level="trusted"}, "<trust_dir_2>"={trust_level="trusted"} }` を注入する（Q-001=C）
    - git でない場合: effective `--cd` ディレクトリを `trust_dir` として注入する（Q-002=B）
  - `sandbox codex` は **設定ファイル（`~/.codex/config.toml` 等）を作成/更新しない**（永続設定の汚染をしない）。
  - git 判定/取得に失敗しても、`sandbox codex` 自体は起動できる（エラーで落とさない）。必要なら警告を出す。
- MUST NOT（絶対にやらない／追加しない）:
  - 外部ツールで `~/.codex/config.toml`（または `.agent-home/.codex/config.toml`）の `[projects]` を機械的に追記/編集しない。
  - trust を永続化するための独自 DB/キャッシュ/設定ファイルを追加しない。
  - docker / git を実環境で叩くことを前提にした自動テストを追加しない（テストは既存 stub 方式に従う）。
- OUT OF SCOPE（今回やらない）:
  - Codex CLI 本体（openai/codex）の改修（上流修正）。
  - コンテナイメージ内の `/etc/codex/config.toml` など、Codex の system layer を書き換える方式。
  - `sandbox shell` 内でユーザーが直接 `codex` を打つケースを完全に透過的に直す（要件化する場合は別途）。
  - `sandbox shell` で起動される “プレーンな codex” の挙動（trust 画面表示、権限変更の運用）は Codex 標準に委ねる（ラッパー/自動注入はしない）。

## 非交渉制約（守るべき制約） (必須)
- Bash-first: `host/sandbox` は `#!/bin/bash` + `set -euo pipefail` 前提で、明示的な quoting と `local` を守る。
- テストは `tests/*.test.sh` の stub 方式を維持し、実 Docker/Git に依存しない。
- 禁止 Git コマンド（`git add/commit/push/merge`）は実装フェーズでも実行しない（本環境の制約）。

## 前提（Assumptions） (必須)
- `sandbox codex` は「外部で隔離された環境（Docker コンテナ）」として運用され、Codex に最大権限を付与してよい前提がある。
- mount-root / workdir は `host/sandbox` が決定し、コンテナ側では `/srv/mount` 配下に配置される。
- trust の注入は **その実行の中でのみ効けばよい**（永続設定は不要/避けたい）。

## 判断材料/トレードオフ（Decision / Trade-offs） (任意)
- 論点: git worktree の trust 対象をどこにするか（worktree root / main repo root / 両方）
  - 影響: trust のスコープ、複数 worktree 並行時の扱い、将来の拡張性
  - 決定: 両方（Q-001=C）
- 論点: git でないディレクトリを trust 注入するか
  - 影響: `.codex` が存在する非 git プロジェクトでの skills/rules、有効化範囲（安全性/期待値）
  - 決定: effective `--cd` を trust（Q-002=B）

## リスク/懸念（Risks） (任意)
- R-001: `-c` の dotted path 方式（例: `projects."<path>".trust_level=...`）はパスに `.` が含まれると壊れる。
  - 対応: inline table で `projects={ "<path>"={trust_level="trusted"} }` を採用する。
- R-002: 自動 trust 注入は、Codex の trust モデル（ユーザー承認）をバイパスする。
  - 対応: 本ツールの前提（外部隔離された環境で最大権限）として要件に明記し、opt-out は提供しない（Q-003=A）。

## 受け入れ条件（観測可能な振る舞い） (必須)
- AC-001:
  - Actor/Role: 利用者
  - Given: git repo 配下で `sandbox codex` を実行する
  - When: `sandbox codex` が `codex resume` を起動する
  - Then: `codex resume` に以下のデフォルト引数が付与される（ユーザー指定がない場合）:
    - `--ask-for-approval never`
    - `--sandbox danger-full-access`
    - `--cd .`
    - `-c projects={ "<trust_dir_1>"={trust_level="trusted"}, "<trust_dir_2>"={trust_level="trusted"} }`
      - `trust_dir_1` = worktree root（`git rev-parse --show-toplevel`）
      - `trust_dir_2` = root git project for trust（`dirname "$(git rev-parse --git-common-dir)"`）
      - いずれも `/srv/mount/...` に写像され、同一なら重複は除外される
  - 観測点: `tests/sandbox_cli.test.sh` の compose stub ログ（= 起動コマンドの文字列）
- AC-002:
  - Actor/Role: 利用者
  - Given: git repo 直下に `.codex/skills/**/SKILL.md` が存在する
  - When: `sandbox codex` を起動する
  - Then: Codex が repo-scope skills を認識して利用可能になる
  - 観測点: 手動確認（詳細手順は `.spec-dock/current/discussions/` に記載する）
  - 権限/認可条件: 上記 `-c projects=...` により、当該ディレクトリが trusted 扱いになること
- AC-003:
  - Actor/Role: 利用者
  - Given: git 管理されていないディレクトリで `sandbox codex` を実行する
  - When: trust 対象ディレクトリを git から特定できない
  - Then: `sandbox codex` は起動できる（エラーで落ちない）。trust 注入は **effective `--cd` ディレクトリ**を `trust_dir` として行う。
  - 観測点: compose stub ログ + 期待する終了コード
- AC-004:
  - Actor/Role: 利用者
  - Given: `sandbox codex -- <codex args...>` でユーザーが `-C/--cd` や `-a/-s` を指定している
  - When: `sandbox codex` が `codex resume` を起動する
  - Then: `sandbox codex` は二重指定を避け、ユーザー指定を尊重する（具体ルールは設計で固定）
  - 観測点: compose stub ログ

### 入力→出力例 (任意)
- EX-001（git repo）:
  - Input: `sandbox codex --mount-root <...> --workdir <repo>/subdir`
  - Output（期待）: `codex resume -a never -s danger-full-access -C . -c 'projects={\"/srv/mount/repo\"={trust_level=\"trusted\"},\"/srv/mount/repo-worktree\"={trust_level=\"trusted\"}}'`（同一なら 1 エントリに畳まれる）
- EX-002（non-git）:
  - Input: `sandbox codex --mount-root <...> --workdir <dir>`
  - Output（期待）: `codex resume -a never -s danger-full-access -C . -c 'projects={\"/srv/mount/<dir>\"={trust_level=\"trusted\"}}'`

## 例外・エッジケース（仕様として固定） (必須)
- EC-001:
  - 条件: git repo 配下だが、git コマンドが失敗する（壊れた `.git`、権限不足、など）
  - 期待: `sandbox codex` は起動し、stderr に警告を出してよい。trust 注入は effective `--cd` ディレクトリに fallback する。
  - 観測点: stderr / compose stub ログ
- EC-002:
  - 条件: trust 対象ディレクトリが mount-root の外（`/srv/mount` の外）になってしまう（異常系）
  - 期待: trust 注入は行わず警告する（安全側）。`sandbox codex` 自体は起動できる。
  - 観測点: stderr

## 用語（ドメイン語彙） (必須)
- TERM-001: `runtime trust 注入` = `codex` 実行引数 `-c/--config` により、`projects` の trust を **その実行に限って**上書きすること
- TERM-002: `trust_dir` = `projects` に `trust_level="trusted"` を設定する対象の絶対パス（コンテナ内 `/srv/mount/...`）
- TERM-003: `worktree root` = `git rev-parse --show-toplevel` が返すディレクトリ（通常、現在の worktree ルート）
- TERM-004: `root git project for trust` = `git rev-parse --git-common-dir` の親ディレクトリ（Codex が worktree 群を束ねる単位として使い得る）

## 未確定事項（TBD / 要確認） (必須)
- Q-001（解消済み / 2026-01-25 ユーザー回答: 1c）:
  - 質問: git repo の場合、`trust_dir` はどれにするべきか？
  - 決定: C（A と B の両方を `projects` に注入）
  - 影響範囲: AC-001/002/004, 設計（trust_dir 計算）, テスト（stub）
- Q-002（解消済み / 2026-01-25 ユーザー回答: 2b）:
  - 質問: git でない場合、`trust_dir` をどう扱うべきか？
  - 決定: B（effective `--cd` の対象を `trust_dir` として注入）
  - 影響範囲: AC-003, EC-001, 設計, テスト
- Q-003（解消済み / 2026-01-25 ユーザー回答: 3a）:
  - 質問: `sandbox codex` の自動 trust 注入を無効化するオプションは必要か？
  - 決定: A（不要。常に自動 trust）
  - 影響範囲: `host/sandbox` CLI, ヘルプ, テスト
- Q-004（解消済み / 2026-01-25 ユーザー回答: 4no）:
  - 質問: `sandbox shell` でも “直接 codex を起動して skills が使える” を要件に含めるか？
  - 決定: No（`sandbox shell` はプレーンな codex を使い、trust/UI/権限変更は Codex 標準運用に委ねる）
  - 影響範囲: スコープ（OUT OF SCOPE）と運用説明

## 完了条件（Definition of Done） (必須)
- すべてのAC/ECが満たされる
- 未確定事項が解消される（残す場合は「残す理由」と「合意」を明記）
- MUST NOT / OUT OF SCOPE を破っていない（追加機能を入れていない）
- 自動テスト（proxy）で `sandbox codex` が期待引数を付与していることが担保される
- 手動受け入れ（AC-002）が実施され、ログ/結果が `.spec-dock/current/report.md` に記録される

## 省略/例外メモ (必須)
- 該当なし
