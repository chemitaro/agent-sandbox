---
種別: 設計書
機能ID: "FEATURE-COPILOT-CLI-INTEGRATION"
機能名: "GitHub Copilot CLI を sandbox ツールチェーンへ統合する"
関連Issue: []
状態: "draft"
作成者: "Codex"
最終更新: "2026-03-19"
依存: ["requirement.md"]
---

# FEATURE-COPILOT-CLI-INTEGRATION GitHub Copilot CLI を sandbox ツールチェーンへ統合する — 設計（HOW）

## 目的・制約（要件から転記・圧縮） (必須)
- 目的:
  - GitHub Copilot CLI を既存 CLI 群と同じ sandbox 運用面に統合する
  - `~/.copilot` を `.agent-home/.copilot` から bind mount して永続化する
  - `sandbox copilot` を追加して tmux 経由で起動できるようにする
- MUST:
  - Dockerfile、docker-compose、`host/sandbox`、`package.json`、テストを連動して更新する
  - Copilot CLI の標準ディレクトリを使う
  - `sandbox copilot [options] -- [copilot args...]` の契約を明示し、`--` より後ろは `copilot` へ pass-through する
  - Copilot CLI の非対話・programmatic 利用では tmux を自動バイパスし、標準入出力を親プロセスへ返す
  - `sandbox copilot` は Copilot CLI の終了コードを失わずに呼び出し元へ返す
  - Copilot CLI の非対話経路では `docker compose exec -T` を使い、Compose 既定の TTY 割り当てを無効化する
  - `-p` / `--prompt` を使う programmatic 実行は、`--allow-all-tools` / `--allow-tool ...` / `--allow-all` / `--yolo` または `COPILOT_ALLOW_ALL` による承認オーバーライドがある場合にのみ非対話経路へ流す
  - 対話モードの `copilot` / `copilot --interactive` は TTY 前提のまま扱い、stdin または stdout が非 TTY の場合は非対話経路へ暗黙変換せず明示エラーにする
  - `copilot help [topic]`、`version`、`-v/--version`、stdin からオプション列を受ける headless invocation は tmux を使わず直接実行できる
- MUST NOT:
  - `COPILOT_HOME` による別ディレクトリ設計を持ち込まない
  - `~/.copilot` 以外の追加 XDG/config/cache mount を推測で足さない
  - Copilot 独自の認証/権限制御をラッパーに実装しない
  - 承認オーバーライドが無い `-p` / `--prompt` 実行を「対応済みの非対話フロー」として扱わない
  - 対話モードを stdout リダイレクトやコマンド置換だけを理由に自動で `exec -T` 経路へ落とさない
- 非交渉制約:
  - 既存 `.agent-home` 設計と deterministic な stub テストを維持する
  - 既存 CLI の挙動を壊さない
- 前提:
  - Node.js 24 で npm パッケージ `@github/copilot` を導入できる
  - 標準ディレクトリは `~/.copilot`

---

## 既存実装/規約の調査結果（As-Is / 95%理解） (必須)
- 参照した規約/実装（根拠）:
  - `AGENTS.md`: `print_help*` の更新、Bash-first、テストは stub ベースという規約
  - `docker-compose.yml`: `.agent-home` から各 CLI 標準ディレクトリへの bind mount 定義
  - `Dockerfile`: 各 CLI のホーム配下ディレクトリ事前作成、Node グローバルツール導入前提
  - `package.json`: `install-global` / `verify` による共有ツール管理
  - `host/sandbox`: `.agent-home` 初期化、compose 実行、help、`tools update`、`sandbox codex` の tmux 起動実装
  - `tests/sandbox_cli.test.sh`: `help`、`.agent-home` 作成、`tools update`、`sandbox codex` の仕様テスト
- 観測した現状（事実）:
  - `.agent-home` の初期作成は `ensure_agent_home_dirs` に集中している
  - Docker mount は `docker-compose.yml` の `volumes:` に集中している
  - npm グローバルツールの導入は `package.json` と `sandbox tools update` のみで制御している
  - tmux ラッパー付き専用サブコマンドは現状 `codex` のみ
- 採用するパターン（命名/責務/例外/DI/テストなど）:
  - 新しい CLI の永続化は `.agent-home/.<tool>` を作って標準ディレクトリに mount する
  - ツール導入は `package.json` の `dependencies`、`install-global`、`verify` を揃えて更新する
  - 専用サブコマンドは `print_help_<tool>`、`run_compose_exec_<tool>`、`compute_<tool>_session_name` のように分離し、`main()` に分岐を追加する
  - tmux の有無、help の副作用なし、compose ログ確認は既存 codex テストに倣う
- 採用しない/変更しない（理由）:
  - Codex の Trust/YOLO/bootstrap 判定は Copilot に転用しない
    - 理由: GitHub Copilot CLI の公式仕様で同等概念が確認できず、過剰なラッパー制御になるため
  - `COPILOT_HOME` 環境変数で mount 先を切り替えない
    - 理由: ユーザー要望と標準ディレクトリ運用に反するため
- 影響範囲（呼び出し元/関連コンポーネント）:
  - `sandbox --help` / `sandbox tools --help` / `sandbox copilot --help`
  - `sandbox tools update`
  - `sandbox build` / `up` / `shell` / `copilot` 前処理
  - `tests/sandbox_cli.test.sh`

## 主要フロー（テキスト：AC単位で短く） (任意)
- Flow for AC-001:
  1. `package.json` の `dependencies`、`install-global`、`verify` に Copilot CLI を追加する
  2. `sandbox tools update` は既存と同じ `npm run install-global` を呼ぶ
  3. `npm run verify` で `copilot --version` を追加確認する
- Flow for AC-002:
  1. `ensure_agent_home_dirs` に `.agent-home/.copilot` を追加する
  2. `Dockerfile` で `/home/node/.copilot` を事前作成する
  3. `docker-compose.yml` で `.agent-home/.copilot:/home/node/.copilot` を mount する
- Flow for AC-003:
  1. `sandbox copilot` 実行時、外側では tmux セッションの存在を確認する
  2. `-p` / `--prompt`、`help`、`version`、`-v/--version`、または stdin 非 TTYかつ引数空のケースを headless invocation とみなす
  3. `-p` / `--prompt` を含む headless invocation では、`--allow-all-tools` / `--allow-tool ...` / `--allow-all` / `--yolo` / `COPILOT_ALLOW_ALL` を検査する
  4. `-p` / `--prompt` で承認オーバーライドが揃っている場合のみ tmux をバイパスして `docker compose exec -T` の直接実行へ進む
  5. `help` / `version` / stdin オプション入力の headless invocation は、承認オーバーライド不要で直接実行へ進む
  6. `-p` / `--prompt` で承認オーバーライドが無い場合は、必要なフラグまたは環境変数を案内して明示エラーにする
  7. headless invocation でない場合は対話モードとして扱い、`stdin` と `stdout` の両方が TTY のときだけ tmux セッションを生成または再利用する
  8. 対話モードで `stdin` または `stdout` のどちらかが非 TTY の場合は、非対話経路へ暗黙変換せず明示エラーにする
  9. 内側フローでは `determine_paths`、Docker/Compose 準備、`run_compose_up`
  10. sandbox オプションは `--` の手前までで解釈し、`--` より後ろは `copilot` 引数として保持する
  11. 対話実行では `copilot` 成功時のみ zsh に戻し、失敗時は Copilot の終了コードで終了する
  12. 非対話実行では `docker compose exec -T` で `copilot` だけを実行し、終了コードと標準入出力をそのまま返す
- Flow for AC-004:
  1. help 表示時は `copilot` サブコマンドを認識する
  2. ただちに help テキストだけを返し、副作用を起こさない

## 判断材料/トレードオフ（Decision / Trade-offs） (任意)
- 論点: `sandbox copilot` でコマンド名を固定するか、将来 `copilot agent` などに拡張可能な抽象化を先に入れるか
  - 選択肢A: 初期実装では `copilot` 単体起動に固定する
  - 選択肢B: 汎用エージェント起動ラッパーへ抽象化する
  - 決定: 選択肢A
  - 理由: 既存実装が CLI ごとの明示実装であり、変更範囲を最小にできるため

## インターフェース契約（ここで固定） (任意)
### 関数・クラス境界（重要なものだけ）
- IF-001: `host/sandbox::ensure_agent_home_dirs()`
  - Input: なし
  - Output: `.agent-home/.copilot` を含む必要ディレクトリが存在する
  - Errors/Exceptions: 作成不能時は `mkdir -p` 失敗で終了
- IF-002: `host/sandbox::run_compose_exec_copilot(container_workdir, container_name, compose_project_name, abs_mount_root, [copilot_args...])`
  - Input: container workdir と compose 実行文脈、任意の Copilot 引数
  - Output: コンテナ内で `copilot` を実行し、対話実行では成功時のみ zsh に戻る。非対話実行では `-T` 付き exec で標準入出力を親へ返す
  - Errors/Exceptions: Copilot または compose exec の終了コードをそのまま返す
- IF-005: `host/sandbox::split_copilot_args()`
  - Input: `sandbox copilot` に渡された全引数
  - Output: sandbox 側引数と `--` 以降の `copilot` 側引数を分離する
  - Errors/Exceptions: `--` が無い場合は Copilot 引数を空配列として扱う
- IF-006: `host/sandbox::copilot_requests_programmatic_mode([copilot_args...])`
  - Input: `copilot` へ渡す引数配列
  - Output: `-p` / `--prompt` など、programmatic 利用を示すフラグの有無を判定する
  - Errors/Exceptions: なし
- IF-010: `host/sandbox::copilot_requests_headless_mode([copilot_args...])`
  - Input: `copilot` へ渡す引数配列と stdin の TTY 状態
  - Output: `-p` / `--prompt`、`help`、`version`、`-v/--version`、stdin オプション入力など、tmux を使わず直接実行すべき headless invocation かを判定する
  - Errors/Exceptions: なし
- IF-008: `host/sandbox::copilot_has_approval_override([copilot_args...])`
  - Input: `copilot` へ渡す引数配列と `COPILOT_ALLOW_ALL`
  - Output: `--allow-all-tools`、`--allow-tool ...`、`--allow-all`、`--yolo`、`COPILOT_ALLOW_ALL` のいずれかで非対話実行に必要な承認オーバーライドが存在するかを判定する
  - Errors/Exceptions: なし
- IF-009: `host/sandbox::validate_copilot_invocation([copilot_args...])`
  - Input: 現在の stdin/stdout の TTY 状態、`copilot` 引数、`COPILOT_ALLOW_ALL`
  - Output: 呼び出しが対話モードとして成立するか、または headless invocation の前提を満たしているかを検証する
  - Errors/Exceptions: 前提不足時は stderr に補正方法を出して非 0 を返す
- IF-007: `host/sandbox::copilot_should_use_tmux([copilot_args...])`
  - Input: 現在の stdin/stdout の TTY 状態と `copilot` 引数
  - Output: 妥当な対話実行なら 0、headless invocation または tmux 不使用なら非 0
  - Errors/Exceptions: なし
- IF-003: `host/sandbox::compute_copilot_session_name()`
  - Input: `CALLER_PWD`
  - Output: `<sanitized-base>-copilot-sandbox`
  - Errors/Exceptions: なし
- IF-004: `host/sandbox::print_help_copilot()`
  - Input: なし
  - Output: `sandbox copilot` の usage と振る舞い説明を stdout へ出す
  - Errors/Exceptions: なし

## 変更計画（ファイルパス単位） (必須)
- 追加（Add）:
  - 該当なし
- 変更（Modify）:
  - `package.json`: `@github/copilot` を dependencies、`install-global`、`verify` に追加する
  - `Dockerfile`: `/home/node/.copilot` の事前作成と所有権設定を追加する
  - `docker-compose.yml`: `.agent-home/.copilot:/home/node/.copilot` mount を追加し、Copilot 用の追加 XDG/config/cache mount は設けない
  - `host/sandbox`: `.agent-home` 初期化、help、subcommand 判定、引数分離、tmux/compose ベースの `sandbox copilot [options] -- [copilot args...]` 実装を追加する
  - `host/sandbox`: Copilot の非対話時 tmux バイパスと、Copilot 終了コードを保持する実行ラッパーに修正する
  - `host/sandbox`: Copilot の非対話時は `docker compose exec -T` を使うよう修正し、stdout リダイレクト時も tmux をバイパスする
  - `host/sandbox`: Copilot の対話/非対話モードを明示判定し、対話モードで TTY が足りない場合は明示エラー、`-p` / `--prompt` では承認オーバーライドを必須化する
  - `host/sandbox`: Copilot の headless invocation を `-p` / `--prompt` 以外にも拡張し、`help` / `version` / stdin オプション入力を tmux なしで直接実行できるようにする
  - `tests/sandbox_cli.test.sh`: help、`.agent-home`、`sandbox copilot`、tmux なしエラー等のテストに加えて、非対話バイパス、`-T` 利用、承認オーバーライド別名、help/version の direct exec、stdin オプション入力、TTY 不足時の明示エラー、終了コード保持のテストを追加・更新する
- 削除（Delete）:
  - 該当なし
- 移動/リネーム（Move/Rename）:
  - 該当なし
- 参照（Read only / context）:
  - `tests/_helpers.sh`: stub/fixture の前提確認
  - `AGENTS.md`: 変更時の運用規約確認

## マッピング（要件 → 設計） (必須)
- AC-001 → `package.json`, `host/sandbox` (`tools update`), `tests/sandbox_cli.test.sh`
- AC-002 → `host/sandbox::ensure_agent_home_dirs`, `Dockerfile`, `docker-compose.yml`, `tests/sandbox_cli.test.sh`
- AC-003 → `host/sandbox::run_compose_exec_copilot`, `host/sandbox::compute_copilot_session_name`, `host/sandbox::print_help_copilot`, `tests/sandbox_cli.test.sh`
- AC-003 → `host/sandbox::split_copilot_args`
- AC-003 → `host/sandbox::copilot_requests_programmatic_mode`, `host/sandbox::copilot_requests_headless_mode`, `host/sandbox::copilot_has_approval_override`, `host/sandbox::validate_copilot_invocation`, `host/sandbox::copilot_should_use_tmux`
- AC-004 → `host/sandbox::print_help`, `host/sandbox::print_help_tools`, `host/sandbox::print_help_copilot`, `tests/sandbox_cli.test.sh`
- EC-001 → `host/sandbox::ensure_tmux_available`, `tests/sandbox_cli.test.sh`
- EC-002 → help 判定ロジック、`tests/sandbox_cli.test.sh`
- EC-003 → 既存 `acquire_tools_update_lock` と `tools update` テストの非回帰確認
- EC-004 → `host/sandbox::ensure_agent_home_dirs`, `Dockerfile`, `docker-compose.yml`, `tests/sandbox_cli.test.sh`
- 非交渉制約 → `.agent-home` ディレクトリ全体 mount、既存 stub テストを継承、Copilot 独自制御を最小化

## テスト戦略（最低限ここまで具体化） (任意)
- 追加/更新するテスト:
  - Unit: なし
  - Integration:
    - `help` に Copilot が反映されること
    - `.agent-home/.copilot` が作成されること
    - `sandbox copilot` の tmux 外側起動と内側 compose exec 起動
    - `sandbox copilot -- --help` と `sandbox copilot -- --version` が direct exec として pass-through されること
    - `echo ... | sandbox copilot ...` のような非対話実行で tmux を使わないこと
    - stdin からオプション列を受ける `copilot` 実行が tmux を使わないこと
    - stdout リダイレクト付きの対話モードは明示エラーになること
    - 非対話実行では `docker compose exec -T` が使われること
    - 非対話実行時に Copilot の失敗終了コードが保持されること
    - `-p` / `--prompt` 実行では `--allow-all-tools` / `--allow-tool` / `--allow-all` / `--yolo` / `COPILOT_ALLOW_ALL` が承認オーバーライドとして認識されること
    - tmux 未導入時にエラー終了すること
  - Frontend: なし
- どのAC/ECをどのテストで保証するか:
  - AC-001 → `tests/sandbox_cli.test.sh` の tools update / verify 関連更新
    - `package.json` の `install-global` に `@github/copilot` が入ること
    - `package.json` の `verify` に `copilot --version` が入ること
  - AC-002 → `tests/sandbox_cli.test.sh` の `.agent-home` 作成確認更新
  - AC-003 → 新規 `copilot_outer_uses_tmux_and_session_name`, `copilot_inner_runs_copilot_and_returns_to_zsh`, `copilot_help_flag_after_double_dash_uses_direct_exec`, `copilot_version_flag_uses_direct_exec`
  - AC-003 → 新規 `copilot_noninteractive_bypasses_tmux`, `copilot_noninteractive_preserves_exit_status`, `copilot_programmatic_requires_approval_override`, `copilot_programmatic_accepts_allow_all_aliases`, `copilot_stdin_option_stream_uses_direct_exec`
  - AC-003 → 新規 `copilot_redirected_stdout_errors_for_interactive_mode`
  - AC-004 → 新規 `help_copilot_mentions_tmux`
  - EC-001 → 新規 `copilot_errors_when_tmux_missing`
  - EC-002 → `help` 系テスト
- 非交渉制約（requirement.md）をどう検証するか:
  - 制約: 標準ディレクトリ `~/.copilot` を使用する
    - 検証方法: `docker-compose.yml` mount 先と `Dockerfile` 作成先を確認する
  - 制約: 既存 CLI の挙動を壊さない
    - 検証方法: 既存 `tests/sandbox_cli.test.sh` を通す
- 実行コマンド（該当するものを記載）:
  - `bash tests/sandbox_cli.test.sh`
  - 必要に応じて `npm run verify`（コンテナ内または build 後）
- 変更後の運用（必要なら）:
  - 移行手順: 既存 `.agent-home` に `.copilot` が無ければ自動生成される
  - ロールバック: 変更を revert すれば Copilot 統合のみ除去可能
  - Feature flag: 不要

## リスク/懸念（Risks） (任意)
- R-001: `sandbox copilot` 用の競合引数制御を入れない場合、将来 CLI 仕様変更に対し柔軟だがラッパー責務は薄くなる
- R-002: help / tests / package install の3点を揃えないと統合の見た目だけ先行する

## 未確定事項（TBD） (必須)
- 該当なし

## 合意済み決定事項 (任意)
- D-001: `sandbox copilot` の CLI 契約は `sandbox copilot [options] -- [copilot args...]` とする
- D-002: `--` より後ろの引数は検証や禁止を行わず、`copilot` へ pass-through する
- D-003: `npm run verify` の Copilot 検証は `copilot --version` に固定する

---

## ディレクトリ/ファイル構成図（変更点の見取り図） (任意)
```text
<repo-root>/
├── Dockerfile                         # Modify
├── docker-compose.yml                 # Modify
├── package.json                       # Modify
├── host/
│   └── sandbox                        # Modify
├── tests/
│   ├── _helpers.sh                    # Read only
│   └── sandbox_cli.test.sh            # Modify
└── .spec-dock/
    └── current/
        ├── requirement.md             # Modify
        ├── design.md                  # Modify
        └── plan.md                    # Modify
```

## 省略/例外メモ (必須)
- UML図は今回の変更が Bash ベースの単一 CLI 統合であり、責務境界がファイル単位で十分追跡可能なため省略する
