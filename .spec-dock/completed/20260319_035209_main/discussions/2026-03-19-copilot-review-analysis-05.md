# 2026-03-19 Copilot Review Analysis 05

## 対象レビュー

### Review-10
- 指摘:
  - `copilot_requests_headless_mode()` が `--acp` を headless invocation として扱っていない

### Review-11
- 指摘:
  - `run_in_pseudo_tty()` が util-linux `script` 実行時に `-e/--return` を付けておらず、子プロセスの終了コードを返さない

## 一次情報

- GitHub Copilot CLI command reference
  - `--acp` は `Start the Agent Client Protocol server.`
  - 出典:
    - https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference
- Copilot CLI ACP server docs
  - `copilot --acp --stdio`
  - `copilot --acp --port 3000`
  - ACP サーバーは stdio または TCP で外部クライアントと接続する前提
  - 出典:
    - https://docs.github.com/en/copilot/reference/copilot-cli-reference/acp-server
- util-linux `script`
  - `-e`, `--return` は child process の exit code を返すためのオプション
  - レビュー指摘は Ubuntu 系 CI での util-linux 挙動に基づく

## 妥当性評価

### Review-10: `--acp` を headless 扱いしていない
- 判定: 妥当
- 理由:
  - `--acp` は ACP server を開始する公式フラグで、interactive shell や tmux UI へ入る性質のものではない
  - 公式ドキュメントも stdio/TCP 経由で他クライアントから接続する headless 運用として説明している
  - 現在の wrapper は `--acp` を対話モード寄りに誤判定するため、`sandbox copilot -- --acp` が TTY エラーになるか、tmux に巻かれる可能性がある
- 優先度見立て:
  - `P2` は妥当
- 対処要否:
  - 必要

### Review-11: `run_in_pseudo_tty()` が util-linux で子プロセスの終了コードを返さない
- 判定: 妥当
- 理由:
  - util-linux `script` では `-e/--return` が無いと `script` 自身の終了コードが返りやすく、子プロセスの non-zero を取りこぼす
  - 現在の `copilot_redirected_stdout_errors_for_interactive_mode` は終了コードを評価しているため、Linux 系ではテストの観測点がずれる
  - これは「テストが失敗する/成功する理由」が本来の wrapper の挙動ではなく `script` の既定動作になる、という意味で妥当な指摘
- 優先度見立て:
  - `P2` は妥当
- 対処要否:
  - 必要

## 推奨対策

### 対策A: `--acp` を headless invocation として追加する
- `copilot_requests_headless_mode()` に `--acp` を追加する
- 必要なら `--stdio` / `--port` は `--acp` と組み合わせてそのまま本体へ渡す
- 方針:
  - ACP は stdio/TCP の direct stdio が必要なので、tmux 経路には入れない

### 対策B: `run_in_pseudo_tty()` の util-linux 経路で `-e` を使う
- 例:
  - `script -q -e -c "$command_string" /dev/null >/dev/null`
- 互換方針:
  - `script -q -e -c ...` が使える環境ではそれを優先
  - BSD 版では従来のフォールバックを維持する
- 目的:
  - Linux/macOS の両方で「子プロセスの終了コード」を正しく観測する

## 結論

- Review-10:
  - 妥当
  - 修正が必要
- Review-11:
  - 妥当
  - 修正が必要

## 次の修正メモ

1. `design.md` に ACP server を headless invocation として追記する
2. `plan.md` に追加修正ステップを積むか、既存 S09 の追補として扱う
3. `host/sandbox` の `copilot_requests_headless_mode()` に `--acp` を追加する
4. `tests/sandbox_cli.test.sh` の `run_in_pseudo_tty()` で util-linux 経路に `-e` を追加する
5. 可能なら `copilot_acp_uses_direct_exec` のようなテストを追加する
