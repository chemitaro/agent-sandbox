# 2026-03-19 Copilot Review Analysis 04

## 対象レビュー

### Review-07
- 指摘:
  - `copilot_requests_headless_mode()` が `help` / `version` しか headless 扱いしておらず、`init` / `update` / `plugin ...` / `login` / `logout` などの公式トップレベルコマンドを非TTY環境で弾いてしまう

### Review-08
- 指摘:
  - `compute_copilot_session_name()` が `basename "$CALLER_PWD"` しか使っていないため、別ディレクトリでも basename が同じなら tmux セッションが衝突する

### Review-09
- 指摘:
  - テストの `script -q /dev/null /bin/bash -lc ...` は util-linux 版 `script` では `/bin/bash` が typescript file 扱いされるため移植性が低く、`--command` または `-c` を使うべき

## 一次情報 / 根拠

- GitHub Copilot CLI command reference:
  - `copilot init`
  - `copilot update`
  - `copilot version`
  - `copilot login`
  - `copilot logout`
  - `copilot plugin`
  - 出典:
    - https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference
- GitHub Copilot CLI plugin reference:
  - `copilot plugin install|uninstall|list|update|disable|enable`
  - 出典:
    - https://docs.github.com/en/enterprise-cloud@latest/copilot/reference/cli-plugin-reference
- `script --help` の系統差:
  - 現在のローカル環境は BSD `script` で `script [-aeFkpqr] [-t time] [file [command ...]]`
  - util-linux 系は `--command` / `-c` を明示する構文が一般的
  - レビュー指摘は Ubuntu/util-linux 互換性の観点

## 妥当性評価

### Review-07: 公式トップレベルコマンドを headless 扱いしていない
- 判定: 妥当
- 理由:
  - 公式リファレンスに `init`, `update`, `version`, `login`, `logout`, `plugin` が独立コマンドとして列挙されている
  - 現在の wrapper は `help` / `version` / stdin オプション入力しか direct exec に流していない
  - そのため `sandbox copilot -- init` のような呼び出しが、非TTY環境だと「interactive なのに TTY が無い」と誤判定される余地がある
- 注意点:
  - `login` 自体は OAuth device flow を伴うので、意味上は対話的な場面もある
  - ただし wrapper の責務は tmux UI 強制ではなく、Copilot CLI 本体へ正式サブコマンドを正しく転送することなので、tmux 前提で縛るべきではない
- 優先度見立て:
  - `P2` は妥当
- 対処要否:
  - 必要

### Review-08: tmux セッション名が basename だけで衝突する
- 判定: 妥当
- 理由:
  - 現在の `compute_copilot_session_name()` は `basename "$CALLER_PWD"` しか使っていない
  - `/work/foo/app` と `/tmp/bar/app` は両方 `app-copilot-sandbox` になり、別プロジェクトでも同一 tmux セッションを共有してしまう
  - これは期待動作ではなく、誤ったプロジェクトの Copilot セッションへ入る不具合になる
- 補足:
  - 同じパターンは `compute_codex_session_name()` にもある
  - 今回の PR レビュー対象は Copilot だが、根本原因は共通ロジックの設計にある
- 優先度見立て:
  - `P2` は妥当
- 対処要否:
  - 必要

### Review-09: `script` テストの util-linux 互換性不足
- 判定: 妥当
- 理由:
  - 現在のテストは BSD/macOS では動くが、レビュー指摘の通り util-linux の `script` とは引数解釈が異なる
  - このリポジトリは Dockerfile 上で Ubuntu 系コンテナ環境を扱っており、Linux 系実行環境でテストが落ちる可能性は現実的
  - テストがレビュー指摘の再現確認にならないのは品質上の問題
- 優先度見立て:
  - `P2` は妥当
- 対処要否:
  - 必要

## 推奨対策

### 対策A: headless サブコマンドの範囲を広げる
- `copilot_requests_headless_mode()` に少なくとも以下を追加する
  - `init`
  - `update`
  - `plugin`
  - `login`
  - `logout`
  - 既存の `help`, `version`, `-v`, `--version`, `--help`
- 方針:
  - 「interactive UI を開始する `copilot` 本体」以外の公式トップレベルサブコマンドは原則 direct exec として扱う

### 対策B: tmux セッション名をフルパス由来に変える
- `basename "$CALLER_PWD"` だけでなく、`CALLER_PWD` 全体を sanitize して使う
- 例:
  - フルパスを sanitize した上で長さ制限のために hash を付ける
  - 形式例:
    - `<basename>-<short-hash>-copilot-sandbox`
    - `<sanitized-full-path-hash>-copilot-sandbox`
- 実用上は basename と hash の組み合わせが見やすい

### 対策C: `script` テストを util-linux / BSD 両対応にする
- 優先案:
  - `script --command` または `script -c` を使える場合はその形式を優先
  - BSD 版では従来形式へフォールバックする小さな helper をテスト内に置く
- 目的:
  - テストをホスト依存にせず、Linux/macOS の両方で通る形にする

## 結論

- Review-07:
  - 妥当
  - 修正が必要
- Review-08:
  - 妥当
  - 修正が必要
- Review-09:
  - 妥当
  - 修正が必要

## 次の実装メモ

1. `copilot_requests_headless_mode()` を「公式トップレベルサブコマンドは direct exec」と読める判定に整理する
2. `compute_copilot_session_name()` はフルパスベースの一意化へ変更する
3. 可能なら `compute_codex_session_name()` も同時に同じ衝突回避方式へ揃えるか、少なくとも影響を明記する
4. `tests/sandbox_cli.test.sh` に `script` 呼び出し helper を入れて util-linux/BSD 両対応にする
