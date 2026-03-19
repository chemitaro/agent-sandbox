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
- [ ] S05: Copilot の非対話利用では tmux をバイパスし、終了コードを保持する
- [ ] S06: Copilot の非対話利用では `docker compose exec -T` を使い、stdout リダイレクト時も tmux を使わない
- [ ] S07: Copilot の対話/非対話モード境界を明示し、対話モードの TTY 不足は明示エラー、`-p` / `--prompt` には承認オーバーライドを必須化する
- [ ] S08: Copilot の headless invocation を公式仕様に合わせ、`--allow-all` / `--yolo` と `help` / `version` / stdin オプション入力を direct exec で扱えるようにする

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
- EC-001 → S05
- EC-005 → S05
- EC-005 → S06
- EC-005 → S07
- EC-005 → S08
- 非交渉制約（標準ディレクトリ運用） → S02
- 非交渉制約（tmux ラッパー） → S03
- 非交渉制約（非対話時は標準入出力と終了コードを保持） → S05
- 非交渉制約（非対話時は TTY を割り当てず、stdout 消費側へ出力を返す） → S06
- 非交渉制約（曖昧なモード切替をせず、前提不足は明示エラーにする） → S07
- 非交渉制約（公式の headless entry point を wrapper が阻害しない） → S08

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
  - 対象テスト: `copilot_outer_uses_tmux_and_session_name`, `copilot_inner_runs_copilot_and_returns_to_zsh`, `copilot_help_flag_after_double_dash_uses_direct_exec`, `copilot_errors_when_tmux_missing`
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
- 追加/更新するテスト: `copilot_outer_uses_tmux_and_session_name`, `copilot_inner_runs_copilot_and_returns_to_zsh`, `copilot_help_flag_after_double_dash_uses_direct_exec`, `copilot_errors_when_tmux_missing`

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

### S05 — Copilot の非対話利用では tmux をバイパスし、終了コードを保持する (必須)
- 対象: AC-003 / EC-001 / EC-005
- 設計参照:
  - 対象IF/API: IF-002, IF-006, IF-007
  - 対象テスト: `copilot_noninteractive_bypasses_tmux`, `copilot_noninteractive_preserves_exit_status`
- このステップで「追加しないこと（スコープ固定）」:
  - Codex サブコマンドの tmux 仕様は変更しない
  - Copilot 固有の引数バリデーションや禁止引数制御は追加しない

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に、このステップの作業ステップ（調査/Red/Green/Refactor/品質ゲート/報告/コミット）を登録した
- 登録例:
  - （調査）PR レビュー指摘と現行 `sandbox copilot` 実装差分の確認
  - （Red）非対話バイパスと終了コード保持の失敗テスト追加
  - （Green）`host/sandbox` の Copilot 実行分岐を修正
  - （Refactor）対話/非対話の責務を整理
  - （品質ゲート）`bash tests/sandbox_cli.test.sh`
  - （報告）`.spec-dock/current/report.md` 更新
  - （コミット）このステップの区切りでコミット

#### 期待する振る舞い（テストケース） (必須)
- Given: `sandbox copilot [options] -- [copilot args...]` が使え、標準入出力が非 TTY であるか、programmatic mode フラグが指定されている
- When: `echo prompt | sandbox copilot --mount-root <root> --workdir <dir> -- -p test -s` のような非対話利用を行う
- Then: tmux を経由せずにコンテナ内 `copilot` を直接実行し、Copilot の終了コードをそのまま返す
- 観測点（UI/HTTP/DB/Log など）: tmux stub ログが空であること、compose exec ログ、終了コード
- 追加/更新するテスト: `copilot_noninteractive_bypasses_tmux`, `copilot_noninteractive_preserves_exit_status`

#### Red（失敗するテストを先に書く） (任意)
- 期待する失敗:
  - 非対話実行でも tmux セッションへ入ってしまう
  - Copilot 失敗時に終了コードが 0 にマスクされる

#### Green（最小実装） (任意)
- 変更予定ファイル:
  - Modify: `host/sandbox`
  - Modify: `tests/sandbox_cli.test.sh`
- 追加する概念（このステップで導入する最小単位）:
  - `copilot_requests_programmatic_mode`
  - `copilot_should_use_tmux`
  - 対話/非対話で分岐する Copilot 実行ラッパー
- 実装方針（最小で。余計な最適化は禁止）:
  - stdin/stdout の TTY 状態と `copilot` 引数を見て tmux 利用要否を判定する
  - 対話実行では成功時のみ zsh に戻し、失敗時は Copilot の終了コードを返す
  - 非対話実行では zsh へ遷移せず、Copilot の終了コードをそのまま返す

#### Refactor（振る舞い不変で整理） (任意)
- 目的:
  - Copilot の対話/非対話フローを読みやすく分離する
- 変更対象:
  - `host/sandbox`

#### ステップ末尾（省略しない） (必須)
- [ ] 期待するテスト（必要ならフォーマット/リンタ）を実行し、成功した
- [ ] `.spec-dock/current/report.md` に実行コマンド/結果/変更ファイルを記録した
- [ ] `update_plan` を更新し、このステップの作業ステップを完了にした
- [ ] コミットした（エージェント）

### S06 — Copilot の非対話利用では `docker compose exec -T` を使い、stdout リダイレクト時も tmux を使わない (必須)
- 対象: AC-003 / EC-005
- 設計参照:
  - 対象IF/API: IF-002, IF-007
  - 対象テスト: `copilot_noninteractive_bypasses_tmux`, `copilot_redirected_stdout_errors_for_interactive_mode`, `copilot_noninteractive_preserves_exit_status`
- このステップで「追加しないこと（スコープ固定）」:
  - Copilot の引数体系や programmatic mode 判定条件自体は広げない
  - Codex サブコマンドの exec/TTY 仕様は変更しない

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に、このステップの作業ステップ（調査/Red/Green/Refactor/品質ゲート/報告/コミット）を登録した
- 登録例:
  - （調査）PR レビュー指摘と現在の S05 実装との差分確認
  - （Red）`-T` 未付与と stdout リダイレクト時 tmux 使用の失敗テスト追加
  - （Green）`host/sandbox` の Copilot 非対話 exec と tmux 判定を修正
  - （Refactor）対話/非対話経路の条件整理
  - （品質ゲート）`bash tests/sandbox_cli.test.sh`
  - （報告）`.spec-dock/current/report.md` 更新
  - （コミット）このステップの区切りでコミット

#### 期待する振る舞い（テストケース） (必須)
- Given: `sandbox copilot [options] -- [copilot args...]` を対話シェルやスクリプトから呼び出す
- When: `printf ... | sandbox copilot ...` または `sandbox copilot ... > out.txt` のような非対話利用を行う
- Then: tmux を使わず、`docker compose exec -T` で Copilot を実行し、呼び出し元の stdout/stderr/exit code を保持する
- 観測点（UI/HTTP/DB/Log など）: tmux stub ログ、compose exec ログの `-T`、出力先、終了コード
- 追加/更新するテスト: `copilot_noninteractive_bypasses_tmux`, `copilot_redirected_stdout_errors_for_interactive_mode`, `copilot_noninteractive_preserves_exit_status`

#### Red（失敗するテストを先に書く） (任意)
- 期待する失敗:
  - 非対話経路でも `docker compose exec` に `-T` が付かない
  - stdout リダイレクト時に tmux セッションへ入ってしまう

#### Green（最小実装） (任意)
- 変更予定ファイル:
  - Modify: `host/sandbox`
  - Modify: `tests/sandbox_cli.test.sh`
- 追加する概念（このステップで導入する最小単位）:
  - `stdout` 非 TTY を含む tmux 判定
  - Copilot 非対話 exec の `-T`
- 実装方針（最小で。余計な最適化は禁止）:
  - `copilot_should_use_tmux` は stdin と stdout の両方が TTY のときだけ true にする
  - 非対話経路では常に `docker compose exec -T` を使う

#### Refactor（振る舞い不変で整理） (任意)
- 目的:
  - 非対話経路の契約を条件レベルではっきりさせる
- 変更対象:
  - `host/sandbox`

#### ステップ末尾（省略しない） (必須)
- [ ] 期待するテスト（必要ならフォーマット/リンタ）を実行し、成功した
- [ ] `.spec-dock/current/report.md` に実行コマンド/結果/変更ファイルを記録した
- [ ] `update_plan` を更新し、このステップの作業ステップを完了にした
- [ ] コミットした（エージェント）

### S07 — Copilot の対話/非対話モード境界を明示し、対話モードの TTY 不足は明示エラー、`-p` / `--prompt` には承認オーバーライドを必須化する (必須)
- 対象: AC-003 / EC-005
- 設計参照:
  - 対象IF/API: IF-006, IF-007, IF-008, IF-009
  - 対象テスト: `copilot_programmatic_requires_approval_override`, `copilot_noninteractive_bypasses_tmux`, `copilot_redirected_stdout_errors_for_interactive_mode`
- このステップで「追加しないこと（スコープ固定）」:
  - Copilot の承認仕様をラッパー側で独自実装しない
  - `sandbox codex` など他サブコマンドの TTY 判定は変更しない

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に、このステップの作業ステップ（調査/Red/Green/Refactor/品質ゲート/報告/コミット）を登録した
- 登録例:
  - （調査）最新 PR レビューと現行 S06 実装の差分確認
  - （Red）TTY 不足時の暗黙モード変更と承認不足 `-p` 実行の失敗テスト追加
  - （Green）`host/sandbox` に Copilot 呼び出し前検証を追加
  - （Refactor）programmatic 判定と承認判定の責務分離
  - （品質ゲート）`bash tests/sandbox_cli.test.sh`
  - （報告）`.spec-dock/current/report.md` 更新
  - （コミット）このステップの区切りでコミット

#### 期待する振る舞い（テストケース） (必須)
- Given: `sandbox copilot [options] -- [copilot args...]` を対話シェル、パイプ、リダイレクト、CI から呼び出す
- When: `sandbox copilot > out.txt` のように対話モードなのに TTY が不足している、または `sandbox copilot -- -- -p "fix"` のように承認オーバーライド無しで programmatic mode を要求する
- Then: 対話モードは明示エラーで止まり、programmatic mode は `--allow-all-tools` / `--allow-tool ...` / `COPILOT_ALLOW_ALL` がある場合にのみ `exec -T` 経路へ進む
- 観測点（UI/HTTP/DB/Log など）: stderr のエラーメッセージ、tmux stub ログ、compose exec ログ、終了コード
- 追加/更新するテスト: `copilot_programmatic_requires_approval_override`, `copilot_noninteractive_bypasses_tmux`, `copilot_redirected_stdout_errors_for_interactive_mode`

#### Red（失敗するテストを先に書く） (任意)
- 期待する失敗:
  - 対話モードが stdout リダイレクト時に非対話経路へ暗黙変更される
  - `-p` / `--prompt` が承認オーバーライド無しでも実行される

#### Green（最小実装） (任意)
- 変更予定ファイル:
  - Modify: `host/sandbox`
  - Modify: `tests/sandbox_cli.test.sh`
- 追加する概念（このステップで導入する最小単位）:
  - `copilot_has_approval_override`
  - `validate_copilot_invocation`
- 実装方針（最小で。余計な最適化は禁止）:
  - `-p` / `--prompt` を programmatic mode として扱い、承認オーバーライドの有無を先に検証する
  - programmatic mode でない場合は、stdin と stdout の両方が TTY でない限り明示エラーにする

#### Refactor（振る舞い不変で整理） (任意)
- 目的:
  - Copilot 呼び出し前検証と tmux 判定の責務を分けて読みやすくする
- 変更対象:
  - `host/sandbox`

#### ステップ末尾（省略しない） (必須)
- [ ] 期待するテスト（必要ならフォーマット/リンタ）を実行し、成功した
- [ ] `.spec-dock/current/report.md` に実行コマンド/結果/変更ファイルを記録した
- [ ] `update_plan` を更新し、このステップの作業ステップを完了にした
- [ ] コミットした（エージェント）

### S08 — Copilot の headless invocation を公式仕様に合わせ、`--allow-all` / `--yolo` と `help` / `version` / stdin オプション入力を direct exec で扱えるようにする (必須)
- 対象: AC-003 / EC-005
- 設計参照:
  - 対象IF/API: IF-006, IF-007, IF-008, IF-009, IF-010
  - 対象テスト: `copilot_help_flag_after_double_dash_uses_direct_exec`, `copilot_version_flag_uses_direct_exec`, `copilot_programmatic_accepts_allow_all_aliases`, `copilot_stdin_option_stream_uses_direct_exec`
- このステップで「追加しないこと（スコープ固定）」:
  - wrapper 側で stdin の中身を完全解釈する独自 parser は実装しない
  - Copilot 本体の approval semantics を置き換えない

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に、このステップの作業ステップ（調査/Red/Green/Refactor/品質ゲート/報告/コミット）を登録した
- 登録例:
  - （調査）最新レビューと現行 headless 判定の差分確認
  - （Red）`--allow-all` / `--yolo`、help/version、stdin オプション入力の失敗テスト追加
  - （Green）`host/sandbox` に headless invocation 判定を追加
  - （Refactor）programmatic 判定と headless 判定の責務分離
  - （品質ゲート）`bash tests/sandbox_cli.test.sh`
  - （報告）`.spec-dock/current/report.md` 更新
  - （コミット）このステップの区切りでコミット

#### 期待する振る舞い（テストケース） (必須)
- Given: `sandbox copilot [options] -- [copilot args...]` をスクリプトや CI から呼び出す
- When: `sandbox copilot -- --help` / `sandbox copilot -- --version` / `sandbox copilot -- -p "fix" --allow-all` / `printf '%s\n' --version | sandbox copilot` のような headless invocation を行う
- Then: これらは tmux を使わず `docker compose exec -T` の直接実行へ進み、`--allow-all` と `--yolo` は承認オーバーライドとして受理される
- 観測点（UI/HTTP/DB/Log など）: tmux stub ログ、compose exec ログ、終了コード
- 追加/更新するテスト: `copilot_help_flag_after_double_dash_uses_direct_exec`, `copilot_version_flag_uses_direct_exec`, `copilot_programmatic_accepts_allow_all_aliases`, `copilot_stdin_option_stream_uses_direct_exec`

#### Red（失敗するテストを先に書く） (任意)
- 期待する失敗:
  - `--allow-all` / `--yolo` が approval override として認識されない
  - `--help` / `--version` が tmux 対話経路へ入る
  - stdin からのオプション入力が TTY エラーで止まる

#### Green（最小実装） (任意)
- 変更予定ファイル:
  - Modify: `host/sandbox`
  - Modify: `tests/sandbox_cli.test.sh`
- 追加する概念（このステップで導入する最小単位）:
  - `copilot_requests_headless_mode`
  - `--allow-all` / `--yolo` の approval alias
- 実装方針（最小で。余計な最適化は禁止）:
  - `-p` / `--prompt` は programmatic 判定のまま維持しつつ、tmux 回避条件は `help` / `version` / stdin オプション入力を含む headless invocation に広げる
  - stdin 非 TTYかつ引数空のケースは wrapper が中身を解釈せず、本体に直接渡す

#### Refactor（振る舞い不変で整理） (任意)
- 目的:
  - headless invocation 判定を対話判定から切り離して読みやすくする
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
