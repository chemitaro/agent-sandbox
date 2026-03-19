---
種別: 実装計画書
機能ID: "FEATURE-COPILOT-CLI-INTEGRATION"
機能名: "GitHub Copilot CLI を sandbox ツールチェーンへ統合する"
関連Issue: []
状態: "draft"
作成者: "Codex"
最終更新: "2026-03-19"
依存: ["requirement.md", "design.md"]
---

# FEATURE-COPILOT-CLI-INTEGRATION GitHub Copilot CLI を sandbox ツールチェーンへ統合する — 実装計画（TDD: Red → Green → Refactor）

## この計画で満たす要件ID (必須)
- 対象AC: AC-001, AC-002, AC-003, AC-004
- 対象EC: EC-001, EC-002, EC-003, EC-004, EC-005
- 対象制約（該当があれば）:
  - `.agent-home` ベースの永続化設計を維持する
  - 標準ディレクトリ `~/.copilot` を使う
  - tmux ラッパーを追加する

## ステップ一覧（観測可能な振る舞い） (必須)
- [ ] S01: Copilot CLI が共有 npm グローバルツール群へ追加され、verify 対象にも含まれる
- [ ] S02: Copilot 標準ディレクトリ `~/.copilot` が `.agent-home/.copilot` から永続化される
- [ ] S03: `sandbox copilot` が tmux 経由でコンテナ内 `copilot` を起動できる
- [ ] S04: help とテストが Copilot 統合後の仕様を保証する

### 要件 ↔ ステップ対応表 (必須)
- AC-001 → S01
- AC-002 → S02
- AC-003 → S03
- AC-004 → S04
- EC-001 → S03, S04
- EC-002 → S04
- EC-003 → S01, S04
- EC-004 → S02
- EC-005 → S03
- 非交渉制約（標準ディレクトリ運用） → S02
- 非交渉制約（tmux ラッパー） → S03

---

## 実装ステップ（各ステップは“観測可能な振る舞い”を1つ） (必須)

### S01 — Copilot CLI が共有 npm グローバルツール群へ追加され、verify 対象にも含まれる (必須)
- 対象: AC-001 / EC-003
- 設計参照:
  - 対象IF/API: なし
  - 対象テスト: `tests/sandbox_cli.test.sh::tools_update_runs_compose`、`tests/sandbox_cli.test.sh::package_json_lists_copilot_install_and_verify`
- このステップで「追加しないこと（スコープ固定）」:
  - `sandbox copilot` 本体はまだ追加しない

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に、このステップの作業ステップ（調査/Red/Green/Refactor/品質ゲート/報告/コミット）を登録した
- 登録例:
  - （調査）`package.json` と `tools update` フロー確認
  - （Red）tools update/verify 仕様に関する失敗テスト確認
  - （Green）`package.json` 更新
  - （Refactor）文言・順序整理
  - （品質ゲート）`bash tests/sandbox_cli.test.sh`
  - （報告）`.spec-dock/current/report.md` 更新
  - （コミット）このステップの区切りでコミット

#### 期待する振る舞い（テストケース） (必須)
- Given: sandbox ツール更新フローが有効
- When: `sandbox tools update` を実行する
- Then: Copilot CLI を含む install-global が compose run で呼ばれ、`package.json` の `install-global` に `@github/copilot`、`verify` に `copilot --version` が含まれる
- 観測点（UI/HTTP/DB/Log など）: compose stub ログ、`package.json`
- 追加/更新するテスト: 既存 `tools_update_runs_compose` の非回帰確認、新規 `package_json_lists_copilot_install_and_verify`

#### Red（失敗するテストを先に書く） (任意)
- 期待する失敗:
  - `package.json` に Copilot CLI が無く、verify 対象にも含まれない

#### Green（最小実装） (任意)
- 変更予定ファイル:
  - Modify: `package.json`
- 追加する概念（このステップで導入する最小単位）:
  - npm パッケージ `@github/copilot`
- 実装方針（最小で。余計な最適化は禁止）:
  - `dependencies`、`install-global`、`verify` の3点のみを揃えて更新する

#### Refactor（振る舞い不変で整理） (任意)
- 目的:
  - ツール一覧の順序と可読性を保つ
- 変更対象:
  - `package.json`

#### ステップ末尾（省略しない） (必須)
- [ ] 期待するテスト（必要ならフォーマット/リンタ）を実行し、成功した
- [ ] `.spec-dock/current/report.md` に実行コマンド/結果/変更ファイルを記録した
- [ ] `update_plan` を更新し、このステップの作業ステップを完了にした
- [ ] コミットした（エージェント）

### S02 — Copilot 標準ディレクトリ `~/.copilot` が `.agent-home/.copilot` から永続化される (必須)
- 対象: AC-002 / EC-004
- 設計参照:
  - 対象IF/API: IF-001
  - 対象テスト: `.agent-home` 作成系テスト
- このステップで「追加しないこと（スコープ固定）」:
  - Copilot 固有の cache や追加ディレクトリを推測で増やさない

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に、このステップの作業ステップ（調査/Red/Green/Refactor/品質ゲート/報告/コミット）を登録した
- 登録例:
  - （調査）既存 `.agent-home` mount / Dockerfile 作成先確認
  - （Red）`.agent-home` 作成テストの失敗確認
  - （Green）`Dockerfile`、`docker-compose.yml`、`host/sandbox` 更新
  - （Refactor）mount 一覧の整列
  - （品質ゲート）`bash tests/sandbox_cli.test.sh`
  - （報告）`.spec-dock/current/report.md` 更新
  - （コミット）このステップの区切りでコミット

#### 期待する振る舞い（テストケース） (必須)
- Given: 初回起動で `.agent-home/.copilot` が存在しない
- When: `sandbox up` または `sandbox build` の前処理を実行する
- Then: `.agent-home/.copilot` が作成され、コンテナ標準ディレクトリ `/home/node/.copilot` へ mount される
- 観測点（UI/HTTP/DB/Log など）: `.agent-home` 配下、`docker-compose.yml`、`Dockerfile`
- 追加/更新するテスト: `.agent-home` 作成系テスト

#### Red（失敗するテストを先に書く） (任意)
- 期待する失敗:
  - `.agent-home/.copilot` が作成されない

#### Green（最小実装） (任意)
- 変更予定ファイル:
  - Modify: `host/sandbox`
  - Modify: `Dockerfile`
  - Modify: `docker-compose.yml`
- 追加する概念（このステップで導入する最小単位）:
  - `.agent-home/.copilot` と `/home/node/.copilot` の対応
- 実装方針（最小で。余計な最適化は禁止）:
  - 既存ツールと同じく標準ディレクトリ全体を 1 mount で扱う

#### Refactor（振る舞い不変で整理） (任意)
- 目的:
  - mount 一覧とディレクトリ作成一覧の整合
- 変更対象:
  - `host/sandbox`, `Dockerfile`, `docker-compose.yml`

#### ステップ末尾（省略しない） (必須)
- [ ] 期待するテスト（必要ならフォーマット/リンタ）を実行し、成功した
- [ ] `.spec-dock/current/report.md` に実行コマンド/結果/変更ファイルを記録した
- [ ] `update_plan` を更新し、このステップの作業ステップを完了にした
- [ ] コミットした（エージェント）

### S03 — `sandbox copilot` が tmux 経由でコンテナ内 `copilot` を起動できる (必須)
- 対象: AC-003 / EC-001
- 設計参照:
  - 対象IF/API: IF-002, IF-003, IF-005
  - 対象テスト: `copilot_outer_uses_tmux_and_session_name`, `copilot_inner_runs_copilot_and_returns_to_zsh`, `copilot_help_flag_after_double_dash_is_passed_to_copilot`, `copilot_errors_when_tmux_missing`
- このステップで「追加しないこと（スコープ固定）」:
  - Copilot 独自の権限モード切替や Trust 制御は追加しない

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に、このステップの作業ステップ（調査/Red/Green/Refactor/品質ゲート/報告/コミット）を登録した
- 登録例:
  - （調査）`sandbox codex` の tmux/compose 実装確認
  - （Red）Copilot サブコマンドの失敗テスト追加
  - （Green）`host/sandbox` に `sandbox copilot` 実装
  - （Refactor）共通化できる最小範囲を整理
  - （品質ゲート）`bash tests/sandbox_cli.test.sh`
  - （報告）`.spec-dock/current/report.md` 更新
  - （コミット）このステップの区切りでコミット

#### 期待する振る舞い（テストケース） (必須)
- Given: Docker と tmux が使え、`sandbox copilot [options] -- [copilot args...]` の契約がある
- When: `sandbox copilot --mount-root <root> --workdir <subdir> -- --help` を実行する
- Then: 外側は tmux セッションを張り、内側は compose up 後に `copilot --help` を `container_workdir` で実行する
- 観測点（UI/HTTP/DB/Log など）: tmux stub ログ、compose stub ログ
- 追加/更新するテスト: `copilot_outer_uses_tmux_and_session_name`, `copilot_inner_runs_copilot_and_returns_to_zsh`, `copilot_help_flag_after_double_dash_is_passed_to_copilot`, `copilot_errors_when_tmux_missing`

#### Red（失敗するテストを先に書く） (任意)
- 期待する失敗:
  - `copilot` サブコマンドが未定義
  - tmux セッション名や compose exec が期待通りにならない

#### Green（最小実装） (任意)
- 変更予定ファイル:
  - Modify: `host/sandbox`
  - Modify: `tests/sandbox_cli.test.sh`
- 追加する概念（このステップで導入する最小単位）:
  - `run_compose_exec_copilot`
  - `compute_copilot_session_name`
  - `split_copilot_args`
- 実装方針（最小で。余計な最適化は禁止）:
  - `sandbox codex` の tmux ラッパーを参考にしつつ、Copilot 固有ロジックは持たず単純に `copilot` 実行へ絞る
  - `--` より後ろの引数は無加工で `copilot` に渡す

#### Refactor（振る舞い不変で整理） (任意)
- 目的:
  - Codex/Copilot 間で重複する tmux 分岐を安全に整理する
- 変更対象:
  - `host/sandbox`

#### ステップ末尾（省略しない） (必須)
- [ ] 期待するテスト（必要ならフォーマット/リンタ）を実行し、成功した
- [ ] `.spec-dock/current/report.md` に実行コマンド/結果/変更ファイルを記録した
- [ ] `update_plan` を更新し、このステップの作業ステップを完了にした
- [ ] コミットした（エージェント）

### S04 — help とテストが Copilot 統合後の仕様を保証する (必須)
- 対象: AC-004 / EC-002 / EC-003
- 設計参照:
  - 対象IF/API: IF-004
  - 対象テスト: help 系テスト一式
- このステップで「追加しないこと（スコープ固定）」:
  - ドキュメントサイトや README の大規模更新はしない
  - 起動フロー本体や `--` pass-through 実装はここで広げない

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に、このステップの作業ステップ（調査/Red/Green/Refactor/品質ゲート/報告/コミット）を登録した
- 登録例:
  - （調査）既存 help 文面の構成確認
  - （Red）help 期待値テスト追加
  - （Green）help 文面更新、テスト調整
  - （Refactor）文言統一
  - （品質ゲート）`bash tests/sandbox_cli.test.sh`
  - （報告）`.spec-dock/current/report.md` 更新
  - （コミット）このステップの区切りでコミット

#### 期待する振る舞い（テストケース） (必須)
- Given: 利用者が help を見る
- When: `sandbox --help`、`sandbox tools --help`、`sandbox copilot --help` を実行する
- Then: Copilot CLI の存在と使い方が副作用なしで分かり、`sandbox copilot --help` は sandbox help、`sandbox copilot -- --help` は Copilot help として役割分担が明確である
- 観測点（UI/HTTP/DB/Log など）: stdout、ファイル副作用なし
- 追加/更新するテスト: `help_top_level`, `help_subcommand`, `help_copilot_mentions_tmux`

#### Red（失敗するテストを先に書く） (任意)
- 期待する失敗:
  - help に Copilot が出ない

#### Green（最小実装） (任意)
- 変更予定ファイル:
  - Modify: `host/sandbox`
  - Modify: `tests/sandbox_cli.test.sh`
- 追加する概念（このステップで導入する最小単位）:
  - `copilot` help 文言
- 実装方針（最小で。余計な最適化は禁止）:
  - 既存 help パターンに Copilot を追加し、副作用なしテストで担保する

#### Refactor（振る舞い不変で整理） (任意)
- 目的:
  - help 文面を CLI 一覧として自然に保つ
- 変更対象:
  - `host/sandbox`

#### ステップ末尾（省略しない） (必須)
- [ ] 期待するテスト（必要ならフォーマット/リンタ）を実行し、成功した
- [ ] `.spec-dock/current/report.md` に実行コマンド/結果/変更ファイルを記録した
- [ ] `update_plan` を更新し、このステップの作業ステップを完了にした
- [ ] コミットした（エージェント）

---

## 未確定事項（TBD） (必須)
- 該当なし

## 合意済み決定事項 (任意)
- D-001: `sandbox copilot` の CLI 契約は `sandbox copilot [options] -- [copilot args...]`
- D-002: `--` より後ろの引数は `copilot` へ pass-through する
- D-003: `verify` の Copilot 検証は `copilot --version` に固定する

## 完了条件（Definition of Done） (必須)
- 対象AC/ECがすべて満たされ、テストで保証されている
- MUST NOT / OUT OF SCOPE を破っていない
- 品質ゲート（`bash tests/sandbox_cli.test.sh`、必要に応じて `npm run verify`）が満たされている

## 省略/例外メモ (必須)
- 該当なし
