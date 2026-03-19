# 2026-03-19 Copilot Review Analysis 03

## 対象レビュー

### Review-05
- 指摘:
  - `copilot_has_approval_override()` が `--allow-all` と `--yolo` を承認オーバーライドとして認識していない
- 対象箇所:
  - [host/sandbox](/Users/iwasawayuuta/workspace/box/host/sandbox)

### Review-06
- 指摘:
  - `copilot_requests_programmatic_mode()` が `-p/--prompt` しか見ておらず、stdin 経由のオプション入力や `copilot help [topic]` / `--version` のような非対話エントリポイントを非対話扱いできていない
- 対象箇所:
  - [host/sandbox](/Users/iwasawayuuta/workspace/box/host/sandbox)

## 一次情報

- GitHub Copilot CLI command reference
  - `--allow-all` は `--allow-all-tools --allow-all-paths --allow-all-urls` と等価
  - `--yolo` は `--allow-all` と等価
  - `--allow-all-tools` は programmatic usage で必要
  - `copilot help [topic]` と `-v/--version` は独立したヘッドレスなコマンド/フラグ
  - 出典:
    - https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference
- About GitHub Copilot CLI
  - programmatic interface は `-p/--prompt` だけでなく、オプション列を出力するスクリプトを `./script-outputting-options.sh | copilot` のように stdin で流す方法も案内されている
  - 出典:
    - https://docs.github.com/en/copilot/concepts/agents/copilot-cli/about-copilot-cli

## 妥当性評価

### Review-05: `--allow-all` / `--yolo` 未認識
- 判定: 妥当
- 理由:
  - 公式リファレンスで `--allow-all` と `--yolo` は明示的に承認オーバーライドとして定義されている
  - 現在の wrapper は `--allow-all-tools` と `--allow-tool`、`COPILOT_ALLOW_ALL` しか見ていないため、公式に有効なフラグを wrapper 側で先に弾いてしまう
  - これは Copilot CLI 本体の正当な呼び出しを wrapper が不当に狭めている
- 重大度見立て:
  - `P2` は妥当
  - programmatic 実行の一部の正式フラグが使えず、CI やスクリプト化の互換性を損なう
- 対処要否:
  - 必要

### Review-06: stdin/help/version を非対話エントリポイントとして扱えていない
- 判定: 概ね妥当
- 理由:
  - `copilot help [topic]` と `--version` は公式の独立コマンド/フラグであり、tmux セッションを作って `exec /bin/zsh` に戻るのは過剰
  - 公式ドキュメントは stdin からオプション列を `copilot` に流す使い方も示しているため、wrapper が `stdin 非 TTY = 対話失敗` とだけ扱うのは狭すぎる
  - 現在の `validate_copilot_invocation()` は `-p/--prompt` を伴わない stdin パイプをすべて対話モード失敗として扱うため、公式の headless entry point と矛盾する
- 注意点:
  - stdin パイプは「常に無条件許可」でよいとは限らない
  - stdin に流れてくる内容が `--allow-all` などを含む場合、wrapper は事前に引数列を見られない
  - したがって「stdin パイプを完全に検査してから許可する」のは難しい
  - ここは wrapper の責務と Copilot CLI 本体の責務を切り分けて設計する必要がある
- 重大度見立て:
  - `P2` は妥当
  - `help` / `version` のような明確な非対話ケースも現状は対話経路へ寄っており、wrapper の UX と自動化適性を下げている
- 対処要否:
  - 必要

## 推奨対策

### 対策A: 承認オーバーライド判定を公式同等に拡張する
- `copilot_has_approval_override()` に以下を追加する
  - `--allow-all`
  - `--allow-all=*`
  - `--yolo`
  - `--yolo=*`
- 実質的には `--allow-all-tools` / `--allow-tool` / `--allow-all` / `--yolo` / `COPILOT_ALLOW_ALL` のいずれかを許可条件とする
- 方針:
  - wrapper 独自の approval model は増やさず、公式で承認オーバーライドとして定義されたものだけを通す

### 対策B: 非対話エントリポイントを `-p/--prompt` 以外にも拡張する
- 少なくとも以下は「tmux ではなく直接実行」に寄せるべき
  - `--version`
  - `-v`
  - `version`
  - `help`
- これらは tool approval を伴わない参照系コマンドなので、非対話 direct path に安全に流しやすい

### 対策C: stdin パイプ入力は `-p` 検出だけで判定しない
- 推奨:
  - `stdin` 非 TTYかつ `copilot` 引数が空、または `help` / `version` 系なら direct path を許可する
  - `stdin` 非 TTYかつ引数があり、かつそれが明らかに対話モードではない場合も direct path を検討する
- 設計上の注意:
  - stdin から渡されたオプション列の中身を wrapper が事前検証できないため、approval requirement の最終判定は Copilot CLI 本体に委ねる場面が残る
  - つまり stdin パイプ入力は「wrapper が検査して許可する経路」ではなく、「tmux に入れず直接実行し、本体に解釈させる経路」として扱うのが現実的

## 実装修正の方向性

### `copilot_has_approval_override()`
- 追加候補:
  - `--allow-all`
  - `--yolo`
  - 必要なら `--allow-all=*` / `--yolo=*` を許容するパターンも入れる

### `copilot_requests_programmatic_mode()` の見直し
- 現状:
  - `-p/--prompt` だけを programmatic mode と判定
- 推奨:
  - 関数名/責務を広げる
  - 例:
    - `copilot_should_use_direct_exec()`
    - `copilot_is_headless_invocation()`
- 判定対象:
  - `-p`, `--prompt`
  - `help`, `version`, `-v`, `--version`
  - `stdin` 非 TTYかつ引数空

### `validate_copilot_invocation()` の見直し
- 参照系 direct path:
  - `help` / `version` は承認オーバーライド不要で直接実行
- programmatic direct path:
  - `-p/--prompt` は承認オーバーライドがある場合のみ wrapper で許可
  - ただし stdin パイプでオプション列そのものを渡すケースは wrapper から完全検査できないため、tmux を避けて本体に任せる方が自然
- interactive path:
  - `copilot` のみ、または `--interactive` を含むケースは TTY 必須

## 結論

- Review-05:
  - 妥当
  - 修正が必要
- Review-06:
  - 概ね妥当
  - 修正が必要
  - ただし「stdin パイプ入力をどう安全に扱うか」は wrapper 側で事前検査しきれないため、`help` / `version` / 引数空パイプを direct path に逃がし、それ以外は Copilot 本体へ委ねる設計整理が必要

## 次のアクション案

1. 設計書を更新して、Copilot の direct path 条件を「programmatic mode」から「headless invocation」に整理し直す
2. 実装計画書に追加ステップを積み、`--allow-all` / `--yolo` と `help` / `version` / stdin パイプ対応を追加する
3. テストを追加する
   - `sandbox copilot -- --version` が tmux を使わず終了する
   - `sandbox copilot -- help` が tmux を使わず終了する
   - `sandbox copilot -- -p ... --allow-all` を許可する
   - `sandbox copilot -- -p ... --yolo` を許可する
   - `printf '%s\n' --version | sandbox copilot` のような stdin 経由を direct path に流す
