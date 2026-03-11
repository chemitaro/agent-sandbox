---
種別: 要件定義書
機能ID: "fix-fzf-plugin-startup"
機能名: "zsh startup から fzf plugin を外して shell 初期化エラーを防ぐ"
関連Issue: ["user-request-2026-03-11-fzf-plugin"]
状態: "approved"
作成者: "Codex"
最終更新: "2026-03-11"
---

# fix-fzf-plugin-startup zsh startup から fzf plugin を外して shell 初期化エラーを防ぐ — 要件定義（WHAT / WHY）

## 目的（ユーザーに見える成果 / To-Be） (必須)
- sandbox コンテナの `zsh` 起動時に `fzf_setup_using_debian` エラーが出ない状態にする。
- `Codex` や sandbox の主要機能に影響を出さず、`fzf` 本体は残したまま `oh-my-zsh` の `fzf` plugin 依存だけを取り除く。

## 背景・現状（As-Is / 調査メモ） (必須)
- 現状の挙動（事実）:
  - `Dockerfile` は `fzf` を install し、`zsh-in-docker` を `-p git -p fzf` で実行している。
  - Ubuntu 24.04 ベース image は `/usr/share/doc/*` を除外するため、`oh-my-zsh` の `fzf` plugin が参照する `key-bindings.zsh` 実体が無い。
  - 対話 `zsh` 起動時に `fzf_setup_using_debian:source:40: no such file or directory` が出る。
- 情報源:
  - `Dockerfile`
  - `.spec-dock/current/discussions/fzf-zsh-root-cause-and-mitigation.md`

## スコープ（暴走防止のガードレール） (必須)
- MUST:
  - `zsh-in-docker` で `fzf` plugin を有効化しない
  - 再発防止の静的テストを追加または更新する
- MUST NOT:
  - `fzf` apt package 自体は削除しない
  - `host/sandbox` の起動フロー変更はしない
- OUT OF SCOPE:
  - guarded な自前 `fzf` 初期化の再導入
  - `host/sandbox` の観測性改善

## 非交渉制約（守るべき制約） (必須)
- 既存の Codex / Claude / Gemini / sandbox 起動機能を壊さない
- 変更は小さく、`Dockerfile` とテストに限定する

## 前提（Assumptions） (必須)
- `fzf` shell integration は必須機能ではなく、削っても主要機能に影響しない

## 受け入れ条件（観測可能な振る舞い） (必須)
- AC-001:
  - Given: `Dockerfile` を読む
  - When: `zsh-in-docker` の plugin 指定を確認する
  - Then: `-p fzf` が存在しない
  - 観測点: `Dockerfile`
- AC-002:
  - Given: テストを実行する
  - When: `Dockerfile` の shell 設定に関する静的テストを確認する
  - Then: `fzf plugin` が無効化されていることを検証できる
  - 観測点: `tests/*.test.sh`

## 例外・エッジケース（仕様として固定） (必須)
- EC-001:
  - 条件: `fzf` apt package は引き続き install されている
  - 期待: shell startup で `fzf` plugin が読み込まれないため、doc path 欠落に依存しない

## 用語（ドメイン語彙） (必須)
- TERM-001: `fzf plugin` = `oh-my-zsh` の `plugins=(... fzf ...)` による shell integration

## 未確定事項（TBD / 要確認） (必須)
- 該当なし

## 完了条件（Definition of Done） (必須)
- `Dockerfile` から `-p fzf` が除去されている
- 対応する静的テストが存在し、成功している

## 省略/例外メモ (必須)
- issue 議論シートを別途作成済み
