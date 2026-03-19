---
種別: ディスカッションメモ
題名: "GitHub Copilot CLI PR レビュー指摘の妥当性分析 その2"
作成者: "Codex"
作成日: "2026-03-19"
関連: ["issue #10", "PR review comments on host/sandbox"]
---

# GitHub Copilot CLI PR レビュー指摘の妥当性分析 その2

## 結論
- Review-03 は「一部妥当だが、指摘どおりの修正をそのまま採るべきとは限らない」です。
- Review-04 は概ね妥当で、少なくとも追加のガードまたは仕様明文化が必要です。

## 対象レビュー

### Review-03
- 指摘:
  - `copilot_should_use_tmux()` が `stdout` 非 TTY を理由に tmux を外すと、`sandbox copilot -- --interactive ... | tee ...` や `sandbox copilot > transcript.txt` のようなケースでも interactive UI が起動できなくなる
- 指摘重大度:
  - レビュー上は `P2`

### Review-04
- 指摘:
  - `-p/--prompt` を programmatic mode とみなして非対話経路へ送るだけでは不十分
  - GitHub Docs 上、programmatic usage では `--allow-all-tools` または `COPILOT_ALLOW_ALL` などの approval 設定が必要
  - approval が必要なタスクを非対話経路へ送ると、承認不能で失敗または停止する
- 指摘重大度:
  - レビュー上は `P2`

## 一次情報

### GitHub Docs: Copilot CLI の programmatic interface
- 2026-03-19 時点で GitHub Docs には、`-p` / `--prompt` で programmatic に実行できることが明記されています。
- 同時に、「Copilot にファイル変更やコマンド実行をさせるなら approval option も使うべき」とあります。
- 例:
  - `copilot -p "Show me this week's commits and summarize them" --allow-tool 'shell(git)'`
- 参照:
  - https://docs.github.com/en/copilot/concepts/agents/copilot-cli/about-copilot-cli

### GitHub Docs: approval option
- `--allow-all-tools`
- `--allow-tool`
- `--deny-tool`
- command reference 側では、`--allow-all-tools` は "Required when using the CLI programmatically" と読める説明が載っています。
- 環境変数 `COPILOT_ALLOW_ALL` でも指定可能です。
- 参照:
  - https://docs.github.com/en/free-pro-team@latest/copilot/reference/cli-command-reference
  - https://docs.github.com/en/copilot/how-tos/copilot-cli/set-up-copilot-cli/configure-copilot-cli

## 妥当性分析

## Review-03: `stdout` 非 TTY でも interactive mode は tmux を維持すべきか

### 判断
- 指摘の問題意識は妥当です。
- ただし「stdout 非 TTY なら必ず tmux を使うべき」という結論までは、そのまま採らない方がよいです。

### 妥当な点
- `copilot --interactive` や plain `copilot` は本質的に TTY を必要とする interactive UI です。
- この interactive mode を、stdout リダイレクトだけを理由に `exec -T` な非対話経路へ送ると、UI が成立しない可能性は高いです。
- したがって「stdout 非 TTY なら常に非対話扱い」は雑すぎます。

### そのまま採れない点
- 一方で、stdout リダイレクトや command substitution は「呼び出し元が stdout を消費したい」シグナルでもあります。
- そこへ tmux を強制すると、出力は tmux pane 側へ流れ、リダイレクト先には期待した内容が来ません。
- つまり、以下の2つは両立しません。
  - interactive UI を成立させたい
  - stdout を機械的に取得したい

### 実装上の論点
- `stdout` 非 TTYを見た時点で、その呼び出しが「interactive launcher を期待している」のか「programmatic capture を期待している」のかは、引数情報なしには完全には分かりません。
- そのため、単純に
  - A. `stdout` 非 TTYなら常に非対話
  - B. `stdout` 非 TTYでも常に tmux
  のどちらかに固定すると、片方のユースケースを壊します。

### 推奨判断
- 修正は必要です。
- ただし対策は「tmux を使う」に戻すだけでは不十分です。

### 推奨対策案
- interactive mode を明示するフラグがある場合は、stdout 非 TTYでも「非対話へ落とす」のではなく、明示エラーにする。
  - 例:
    - `sandbox copilot: interactive mode requires a TTY on stdout; remove redirection or use -p/--prompt`
- plain `copilot` で stdout 非 TTY の場合も、同様に
  - 非対話へ暗黙変換するのではなく
  - interactive mode 不能としてエラーにする方が契約は明確
- 一方、programmatic mode (`-p`, `--prompt`) が明示されている場合だけ、stdout 非 TTY でも非対話 `exec -T` に進める

### まとめ
- このレビューは「stdout 非 TTYなら常に非対話」は危険、という点で妥当です。
- ただし実際の対策は「tmux 維持」ではなく、「interactive mode と noninteractive mode を明示的に分け、曖昧なケースはエラーにする」がより堅いです。

---

## Review-04: `-p` を非対話対応とみなすなら approval option も考慮すべきか

### 判断
- 概ね妥当です。

### 理由
- 現在のラッパーは `-p/--prompt` を見つけると noninteractive route へ送ります。
- しかし Copilot がツール実行やファイル編集を要するタスクを行う場合、approval が必要になることがあります。
- 非対話経路では、その approval prompt にユーザーが応答できません。
- そのため、以下の事象が起こり得ます。
  - 実行失敗
  - 承認待ちで停止
  - 期待した自動化ワークフローにならない

### 指摘の強さについて
- 「必ず `--allow-all-tools` が必要」とまでは、文脈上は少し強すぎます。
- 正確には:
  - programmatic usage では approval option の利用が強く推奨または事実上必要
  - 少なくとも、ツール利用が発生するタスクでは approval 設定が無いと非対話では成立しにくい
- したがって、レビューの方向性は正しいです。

### 対策要否
- 必要です。

### 推奨対策案
- 最小対策:
  - `-p/--prompt` で非対話扱いにする場合、approval option が無いときは明示エラーにする
  - 例:
    - `--allow-all-tools`
    - `--allow-tool=...`
    - `--allow-all`
    - `--yolo`
    - `COPILOT_ALLOW_ALL`
- もう一段強い対策:
  - `-p/--prompt` で approval option が無い場合は、非対話 route に送らず interactive route に残す
  - ただしこれは scriptability を下げるため、明示エラーの方が分かりやすい

### 推奨メッセージ例
```text
sandbox copilot: programmatic mode (-p/--prompt) without approval flags is not supported in noninteractive mode.
Pass --allow-all-tools, --allow-tool=..., --allow-all, or set COPILOT_ALLOW_ALL.
```

### 追加テスト案
- `copilot_programmatic_without_approval_flags_errors`
  - `-p` のみ指定して noninteractive 実行すると明示エラーになる
- `copilot_programmatic_with_allow_all_tools_bypasses_tmux`
  - `-p --allow-all-tools` なら `exec -T` 経路へ進む
- `copilot_programmatic_with_env_allow_all_bypasses_tmux`
  - `COPILOT_ALLOW_ALL=1` なら同様に許可

## 優先度評価

### Review-03
- `P2` は妥当です。
- 契約の曖昧さと mode 判定の粗さに関する問題であり、致命的ではないが scriptability と interactive usability の境界を壊します。

### Review-04
- `P2` は妥当、内容次第では `P1` 寄りです。
- 非対話 `-p` の主要用途そのものに関わるため、放置すると「動くが実運用で詰まる」タイプの不具合になります。

## 推奨対応方針

### 対応が必要な点
1. `stdout` 非 TTYだけで即 noninteractive route に落とさない
2. interactive mode を stdout 非 TTYで呼んだ場合の振る舞いを明文化する
3. `-p/--prompt` を noninteractive route に送るなら approval option の有無を検査する

### 実装の方向性
- `copilot_should_use_tmux()` を二段階判定に分ける
  - interactive mode 判定
  - programmatic mode 判定
- `stdout` 非 TTYかつ programmatic mode でない場合:
  - tmux へ送るのではなく、明示エラー
- `-p/--prompt` かつ approval option なし:
  - 明示エラー
- `-p/--prompt` かつ approval option あり:
  - `exec -T` で noninteractive 実行

## まとめ
- Review-03:
  - 妥当
  - ただし「tmux に戻す」だけではなく、interactive/stdout-redirect の曖昧ケースを明示エラーにする方向が望ましい
- Review-04:
  - 概ね妥当
  - 非対話 `-p` をサポートするなら approval flag / env の検査は入れるべき

## 参照
- About GitHub Copilot CLI
  - https://docs.github.com/en/copilot/concepts/agents/copilot-cli/about-copilot-cli
- Configure GitHub Copilot CLI
  - https://docs.github.com/en/copilot/how-tos/copilot-cli/set-up-copilot-cli/configure-copilot-cli
- GitHub Copilot CLI command reference
  - https://docs.github.com/en/free-pro-team@latest/copilot/reference/cli-command-reference
