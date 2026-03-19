---
種別: ディスカッションメモ
題名: "GitHub Copilot CLI PR レビュー指摘の妥当性分析"
作成者: "Codex"
作成日: "2026-03-19"
関連: ["issue #10", "PR review comments on host/sandbox"]
---

# GitHub Copilot CLI PR レビュー指摘の妥当性分析

## 結論
- 2件とも妥当です。
- 1件目は少なくとも `P1` 相当として受けるべき内容です。
- 2件目は少なくとも `P2`、実運用上は `P1` 寄りの内容です。
- どちらも `sandbox copilot` を「対話ラッパー」としては成立させていても、「Copilot CLI の programmatic / scripting usage」を壊すため、修正が必要です。

## 対象レビュー

### Review-01
- 指摘:
  - `docker compose exec` の非対話 Copilot 実行で `-T` を付けていないため、tmux を避けても Compose 側がデフォルトで TTY を割り当ててしまう
  - 結果として、`printf ... | sandbox copilot -- -- -p ...` や CI 実行で TTY 前提の失敗、TTY フォーマット混入、入出力契約の崩れが起こり得る
- 指摘重大度:
  - レビュー上は `P1`

### Review-02
- 指摘:
  - `copilot_should_use_tmux()` が `stdin` しか見ておらず、`stdout` のリダイレクトやコマンド置換を検知できない
  - そのため `sandbox copilot ... > out.txt` や `result=$(sandbox copilot ...)` でも tmux 側へ出力が流れ、呼び出し元が結果を受け取れない
- 指摘重大度:
  - レビュー上は `P2`

## 一次情報

### Docker Compose exec の TTY デフォルト
- Docker Docs の `docker compose exec` には、「コマンドはデフォルトで TTY を割り当てる」と明記されています。
- また `-T, --no-tty` は pseudo-TTY allocation を無効化するオプションです。
- 2026-03-19 時点で確認した公式ドキュメント:
  - https://docs.docker.com/compose/reference/exec

要点:
- By default, Compose will enter container in interactive mode and allocate a TTY.
- `-T` で TTY 無効化が必要。

## 妥当性分析

### 1. `docker compose exec` 非対話経路で `-T` が必要か

#### 判断
- 妥当です。

#### 理由
- 現在の修正案では、tmux をバイパスしても `run_compose exec ...` のままであり、Compose のデフォルト TTY 割り当ては残ります。
- つまり「tmux を避けた」だけで、「非対話・スクリプト実行に適した I/O 条件」にはまだなっていません。
- `copilot -p`、パイプ入力、CI などの programmatic use case では、TTY なし・素の stdin/stdout/stderr を期待するのが自然です。
- ここで TTY が残ると、少なくとも以下のリスクがあります。
  - TTY が必要な前提で失敗する
  - 出力が装飾される
  - 呼び出し元の pipe / redirect と噛み合わない

#### 対策要否
- 必要です。

#### 推奨対策
- Copilot の非対話経路では `docker compose exec -T ...` を使う。
- 対話経路では従来通り TTY ありでよい。

#### 技術的実装案
- `run_compose_exec_copilot()` を対話/非対話で分岐し、非対話時は以下の形にする。

```bash
run_compose exec -T -w "$container_workdir" agent-sandbox /bin/zsh -lc 'copilot "$@"' -- "$@"
```

- 対話時は引き続き `-T` なし。
- 実装上は `interactive_mode=true/false` を受ける現在の関数設計に素直に乗せられる。

#### 追加テスト案
- `copilot_noninteractive_bypasses_tmux` に加えて、compose ログに `exec -T -w ...` が出ることを検証する。
- `copilot_noninteractive_preserves_exit_status` でも `-T` が付いていることを確認する。

---

### 2. `stdin` だけでなく `stdout` リダイレクトも tmux バイパス条件に含めるべきか

#### 判断
- 妥当です。

#### 理由
- 現在の判定は `! -t 0` に寄せており、「stdin が非 TTYなら非対話」とみなしています。
- しかし以下のケースでは stdin は TTY のままでも、呼び出し元は「標準出力を受け取りたい非対話用途」です。
  - `sandbox copilot ... > out.txt`
  - `result=$(sandbox copilot -- -- -p ... -s)`
  - `sandbox copilot ... | jq ...`
- このとき stdout が TTY でなければ、tmux に入る設計は不整合です。
- tmux に attach/switch すると、出力が呼び出し元の stdout に返らず、scriptability を壊します。

#### 対策要否
- 必要です。

#### 推奨対策
- `copilot_should_use_tmux()` は少なくとも以下の条件を満たす場合のみ `true` にする。
  - `stdin` が TTY
  - `stdout` が TTY
  - programmatic mode を示す Copilot 引数が無い
  - テスト用強制フラグが無い限り、非対話シグナルを優先する

#### 技術的実装案

現状:

```bash
if [[ ! -t 0 ]]; then
    return 1
fi
```

修正案:

```bash
if [[ -n "${SANDBOX_COPILOT_FORCE_TMUX:-}" ]]; then
    return 0
fi

if [[ ! -t 0 || ! -t 1 ]]; then
    return 1
fi

if copilot_requests_programmatic_mode "$@"; then
    return 1
fi

return 0
```

補足:
- テスト harness では stdout が TTY でないことが多く、外側 tmux テストが壊れやすいため、`SANDBOX_COPILOT_FORCE_TMUX` は引き続きテスト専用 escape hatch として維持するのが現実的です。
- 本番経路では `stdout` も TTY 条件に含める方が、programmatic contract と整合します。

#### 追加テスト案
- `copilot_noninteractive_bypasses_tmux`
  - stdout リダイレクトや command substitution を模したケースを追加する
  - 例: `"$tmp_dir/host/sandbox" copilot ... >"$tmp_dir/out.txt"` を実行し、tmux ログが空であること
- `copilot_noninteractive_preserves_exit_status`
  - stdout 非 TTY 条件でも exit status が保持されること

## 優先度評価

### Review-01 の優先度
- `P1` は妥当です。
- 理由:
  - 非対話経路を追加した意図そのものを崩す
  - programmatic mode の代表用途に直撃する
  - 修正範囲は比較的局所的

### Review-02 の優先度
- `P2` は妥当、ただし運用影響は大きめです。
- 理由:
  - stdout を消費する利用形態を壊す
  - ただし stdin 非 TTYや `-p/-s` 指定では一部 already mitigated な経路があるため、Review-01 よりは一段落として扱う余地がある

## 推奨対応方針

### 最小で正しい修正
1. 非対話経路の `docker compose exec` に `-T` を付ける
2. `copilot_should_use_tmux()` を `stdin` と `stdout` の両方で判定する
3. 既存の programmatic mode 判定は維持する
4. 既存テストを更新し、stdout 非 TTY 条件でも tmux バイパスを確認する

### 影響ファイル
- `host/sandbox`
- `tests/sandbox_cli.test.sh`
- 必要なら `.spec-dock/current/design.md`
- 必要なら `.spec-dock/current/plan.md`

## まとめ
- 2件ともレビューとして妥当です。
- どちらも `sandbox copilot` の「scriptable である」という期待を守るための指摘です。
- 対策は限定的で、既存設計を壊さずに修正可能です。
- 次の修正では以下を実施するのが適切です。
  - 非対話 `compose exec` に `-T` を追加
  - tmux 利用判定に `stdout` 非 TTY も含める

## 参照
- Docker Docs: `docker compose exec`
  - https://docs.docker.com/compose/reference/exec
