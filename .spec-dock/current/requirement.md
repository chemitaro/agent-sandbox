---
種別: 要件定義書
機能ID: "SBX-CODEX-AUTO-BOOTSTRAP"
機能名: "sandbox codex: Trust状態に応じた自動Bootstrap/YOLO切替"
関連Issue: []
状態: "approved"
作成者: "Codex CLI (GPT-5.2)"
最終更新: "2026-01-26"
---

# SBX-CODEX-AUTO-BOOTSTRAP sandbox codex: Trust状態に応じた自動Bootstrap/YOLO切替 — 要件定義（WHAT / WHY）

## 目的（ユーザーに見える成果 / To-Be） (必須)
- `sandbox codex` を 1 本化し、初回（未Trust）でもプロジェクト skills を確実に有効化できる導線を提供する。
- 2回目以降（Trust済み）は、`approval_policy`/`sandbox_mode` を最大限緩くした状態で Codex を起動できる。
- 外部ツールが `~/.codex/config.toml`（= コンテナ内の `/home/node/.codex/config.toml`）を機械編集せずに運用できる。

## 背景・現状（As-Is / 調査メモ） (必須)
- 現状の挙動（事実）:
  - コンテナ内で `approval_policy="never"` と `sandbox_mode="danger-full-access"` を有効にすると、初回の Trust 導線（TUIの trust onboarding）が抑止され、結果として repo-local の `.codex/skills` が認識されない（未Trust扱いで project config folders が無効化される）。
  - 上記2設定を削除すると Trust 導線が表示され、Trust 登録後は `.codex/skills` が認識される。
  - `-c/--config` による `projects` のランタイム注入は、少なくとも本ユースケース（skills を有効化）では成立しない（仕様上・実装順序上の制約が疑われる）。
- 現状の課題（困っていること）:
  - “最大権限（YOLO相当）” と “プロジェクト skills の安定認識（Trust）” を両立したいが、初回起動時は両立できず手動運用が破綻しやすい。
  - `sandbox codex` を使うたびに、ユーザーが「bootstrap で起動→trust→再起動→yolo」などの判断/切替を手動で行うのは冗長。
- 再現手順（最小で）:
  1) `/srv/mount/<repo>` に `.codex/skills/**/SKILL.md` が存在する状態で、未Trustのまま `codex resume` を `approval_policy="never"` + `sandbox_mode="danger-full-access"` で起動する
  2) skills が認識されない（`.codex/skills` が system prompt に入らない）
- 観測点（どこを見て確認するか）:
  - Log/画面: Codex 起動時の skills 一覧に repo-local skills が出るか
  - 設定: `/home/node/.codex/config.toml`（ホスト側 `.agent-home/.codex/config.toml`）の `[projects."..."] trust_level="trusted"` が作成されるか
  - 自動テスト: `sandbox codex` が実行する `docker compose exec ... codex resume ...` の引数（stubログ）で proxy 観測する
- 実際の観測結果（貼れる範囲で）:
  - `approval_policy/sandbox_mode` を消すと Trust が可能になり、Trust 登録後に skills が認識された
- 情報源（ヒアリング/調査の根拠）:
  - 公式ドキュメント（Codex CLI options / config / security）
  - upstream issue（YOLOとtrust onboarding抑止に関する挙動）※設計書でリンク整理する
  - 本リポジトリ: `host/sandbox`（`sandbox codex` の実装）

## 対象ユーザー / 利用シナリオ (任意)
- 主な利用者（ロール）:
  - Docker コンテナ内で Codex CLI を日常利用する開発者
- 代表的なシナリオ:
  - Git worktree を複数並行で扱い、`sandbox codex` を “1 本” で回したい
  - 初回だけ bootstrap を踏み、2回目以降は最大権限で自律稼働させたい

## スコープ（暴走防止のガードレール） (必須)
- MUST（必ずやる）:
  - `sandbox codex` 実行時に、対象ディレクトリの Trust 状態を判定し、起動モード（bootstrap/yolo）を自動選択する。
  - 対象が Git リポジトリの場合は、`git rev-parse --show-toplevel`（worktreeならworktree root）を Trust 判定対象ディレクトリとして扱う。
  - 未Trust（= config に trust_level が無い）なら bootstrap モードで起動し、Trust 手順と「Trust後に再実行が必要」なことを stderr に案内する。
  - Trust 済みなら YOLO モード（`approval_policy="never"`, `sandbox_mode="danger-full-access"`）で起動する。
  - `codex resume` に `--cd`（コンテナ内の作業ディレクトリ）を必ず付与し、workdir がセッションに反映されることを保証する。
  - ユーザーが競合する Codex 引数（例: `--yolo/--profile/--config/--sandbox/--ask-for-approval/--cd` 等）を渡した場合はエラーにし、`sandbox shell` で素の `codex` を使うよう案内する。
  - 非Gitディレクトリは既定で YOLO モードで起動する。
- MUST NOT（絶対にやらない／追加しない）:
  - 外部ツール（= sandbox 側）が `~/.codex/config.toml` / `.agent-home/.codex/config.toml` の `projects` を機械的に追記・編集して Trust を付与しない。
  - `-c/--config` で `projects` を注入して Trust を成立させる設計にしない（成立しないことが確認されているため）。
  - `sandbox shell` の挙動を変更しない（コンテナ内での素の `codex` 利用は従来どおり）。
- OUT OF SCOPE（今回やらない）:
  - Codex 本体（openai/codex）の挙動変更・上流修正
  - Trust を “自動承認” する（ユーザーの明示操作なしに Trust を付与する）
  - repo-local skills の “直接検出” を自動テストで厳密に行う（本件は proxy + 手動受け入れを正とする）

## 非交渉制約（守るべき制約） (必須)
- `tests/` は実Docker/実Gitを呼ばず、既存stubで決定的に観測する（リポジトリ規約）。
- `sandbox codex` の既存インターフェース（`--mount-root/--workdir` と `--` 以降の args passthrough）を維持する。
- 禁止Git操作（`git add/commit/push/merge`）は行わない（本セッションの運用制約）。

## 前提（Assumptions） (必須)
- `sandbox codex` はコンテナ内で `codex resume` を起動する（現行仕様）。
- Trust の永続化は Codex 標準フロー（TUI等）に委ねることが許容される。
- コンテナ内の Codex 設定はホスト側 `.agent-home/.codex` に永続化される（docker-compose の bind mount）。

## 判断材料/トレードオフ（Decision / Trade-offs） (任意)
- 論点: 非Gitディレクトリの既定モード
  - 選択肢A: 非Gitは常に YOLO（Trustは見ない）
  - 選択肢B: 非Gitも Trust 未確立なら bootstrap（Trust導線を優先）
  - 決定: 選択肢A（回答: 1A）

- 論点: `sandbox codex -- [codex args...]` の競合引数の扱い
  - 選択肢A: 競合引数は拒否してエラー（`sandbox shell` を案内）
  - 選択肢B: 競合引数を許容し、sandbox側の付与は最終（上書き）
  - 選択肢C: 競合引数を許容し、ユーザー指定を優先（上書き）
  - 決定: 選択肢A（回答: 2A）

- 論点: “最大権限” を `--yolo`（bypass）で与えるか、`--sandbox danger-full-access` + `--ask-for-approval never` で与えるか
  - 選択肢A: `--yolo` を使う
    - Pros: 1フラグで分かりやすい
    - Cons: bypass の範囲が広く、意図（danger-full-access だけ欲しい）とズレる可能性
  - 選択肢B: `--sandbox danger-full-access` + `--ask-for-approval never` を使う（推奨）
    - Pros: 要求どおりの “最大権限” を明示できる / 後方互換の期待が高い
    - Cons: 引数が増える
  - 決定: 選択肢B（回答: 3B）

## リスク/懸念（Risks） (任意)
- R-001: Trust 未確立のまま YOLO 起動すると skills が永続的に見えない（影響: 高 / 対応: bootstrap へ自動フォールバック）
- R-002: Codex config のフォーマット差異（`[projects."..."]` vs `projects = { ... }`）で Trust 判定が誤る（影響: 中 / 対応: 代表パターンに対応した堅牢な読み取り）
- R-003: ユーザーが `sandbox codex -- --yolo` 等の競合引数を渡すと設計意図を壊す（影響: 中 / 対応: 競合引数の検知/拒否 or ルール固定）

## 受け入れ条件（観測可能な振る舞い） (必須)
- AC-001: Trust済みGitリポジトリは YOLO モードで起動される（proxy観測）
  - Actor/Role: 開発者
  - Given:
    - `git rev-parse --show-toplevel` が成功し、worktree root が `<repo_root_host>` である
    - `.agent-home/.codex/config.toml` に `<repo_root_container>` の `trust_level="trusted"` が存在する
  - When: `sandbox codex --workdir <repo_subdir>` を実行する
  - Then:
    - `docker compose exec ... codex resume` の引数に `--ask-for-approval never` と `--sandbox danger-full-access` が含まれる
    - `--cd <container_workdir>` が含まれる
  - 観測点: docker compose stub log

- AC-002: 未TrustのGitリポジトリは bootstrap モードで起動され、Trust手順が案内される（proxy+stderr）
  - Actor/Role: 開発者
  - Given:
    - `git rev-parse --show-toplevel` が成功し、worktree root が `<repo_root_host>` である
    - `.agent-home/.codex/config.toml` に `<repo_root_container>` の `trust_level="trusted"` が存在しない
  - When: `sandbox codex --workdir <repo_subdir>` を実行する
  - Then:
    - `docker compose exec ... codex resume` の引数に `--ask-for-approval never`/`--sandbox danger-full-access` が含まれない
    - `--cd <container_workdir>` が含まれる
    - stderr に「Trust を実行してから再実行」する旨の案内が出る
  - 観測点: docker compose stub log / stderr

- AC-003: 非Gitディレクトリでも `sandbox codex` が実行できる（proxy観測）
  - Actor/Role: 開発者
  - Given:
    - `.git` が存在しない（= 非Gitディレクトリ）
  - When: `sandbox codex --workdir <non_git_dir>` を実行する
  - Then:
    - 既定は YOLO モードで起動される
  - 観測点: docker compose stub log

### 入力→出力例 (任意)
- EX-001（Trust済み）:
  - Input: `sandbox codex --workdir <repo>/subdir`
  - Output: `codex resume --cd /srv/mount/<repo>/subdir --sandbox danger-full-access --ask-for-approval never ...`
- EX-002（未Trust）:
  - Input: `sandbox codex --workdir <repo>/subdir`
  - Output: `codex resume --cd /srv/mount/<repo>/subdir ...`（YOLO引数なし）+ stderr に Trust案内

## 例外・エッジケース（仕様として固定） (必須)
- EC-001: `.agent-home/.codex/config.toml` が存在しない
  - 条件: Trust判定に必要な config ファイルが無い
  - 期待: Gitの場合は未Trustとして bootstrap 起動（stderrに案内）。非Gitは YOLO 起動
  - 観測点: stderr / docker compose stub log

- EC-002: `.git` はあるが `git rev-parse --show-toplevel` が失敗する
  - 条件: `git` コマンド実行が失敗（例: Git不整合/権限/壊れたworktree）
  - 期待:
    - stderr に警告を出す（例: “failed to detect git root (rev-parse)”）
    - Trust 判定は諦めて bootstrap で起動する（YOLO にしない）
    - `--cd <container_workdir>` は通常どおり付与する
    - `--skip-git-repo-check` は付与しない
  - 観測点: stderr / docker compose stub log

- EC-003: Trust済みでも `trust_level` が `trusted` 以外
  - 条件: `trust_level` が欠落/未知
  - 期待: 未Trust扱いで bootstrap 起動
  - 観測点: docker compose stub log

## 用語（ドメイン語彙） (必須)
- TERM-001: Trust = Codex が project config folders（例: `.codex/skills`）を読み込むことを許可する状態（`config.toml` の `[projects."..."] trust_level="trusted"`）
- TERM-002: Bootstrap = Trust未確立時に trust onboarding を成立させるため、`approval_policy/sandbox_mode` を指定しないで起動するモード
- TERM-003: YOLO = Trust済み時に `approval_policy="never"` + `sandbox_mode="danger-full-access"` で起動するモード（最大権限）

## 未確定事項（TBD / 要確認） (必須)
- 該当なし（Q-001〜Q-003 は回答済み）

## 完了条件（Definition of Done） (必須)
- すべてのAC/ECが満たされる
- 未確定事項が解消される（残す場合は「残す理由」と「合意」を明記）
- MUST NOT / OUT OF SCOPE を破っていない（追加機能を入れていない）

## 省略/例外メモ (必須)
- 該当なし
