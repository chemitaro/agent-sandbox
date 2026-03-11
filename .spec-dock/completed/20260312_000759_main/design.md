---
種別: 設計書
機能ID: "fix-fzf-plugin-startup"
機能名: "zsh startup から fzf plugin を外して shell 初期化エラーを防ぐ"
関連Issue: ["user-request-2026-03-11-fzf-plugin"]
状態: "approved"
作成者: "Codex"
最終更新: "2026-03-11"
依存: ["requirement.md"]
---

# fix-fzf-plugin-startup — 設計（HOW）

## 目的・制約（要件から転記・圧縮） (必須)
- 目的: `oh-my-zsh` の `fzf` plugin 依存を除去し、startup error を止める
- MUST: `fzf` 本体は残す、変更は小さく保つ
- MUST NOT: wrapper や runtime 設計変更はしない

## 既存実装/規約の調査結果（As-Is / 95%理解） (必須)
- 参照した実装:
  - `Dockerfile`: `zsh-in-docker` に `-p fzf` がある
  - `tests/sandbox_term_env.test.sh`: Dockerfile の静的検証パターンが既にある
- 観測した現状:
  - repo 内で `fzf` を直接使う機能実装はない
  - 問題は `zsh` startup plugin 層に限定される
- 採用するパターン:
  - Dockerfile の静的テストを追加して再発防止する

## 変更計画（ファイルパス単位） (必須)
- 変更（Modify）:
  - `Dockerfile`: `zsh-in-docker` の plugin 指定から `-p fzf` を除去
  - `tests/sandbox_term_env.test.sh`: `-p fzf` が無いことを確認する静的テストを追加

## マッピング（要件 → 設計） (必須)
- AC-001 → `Dockerfile`
- AC-002 → `tests/sandbox_term_env.test.sh`
- EC-001 → `Dockerfile` で `fzf` package を残す構成

## テスト戦略（最低限ここまで具体化） (任意)
- 追加/更新するテスト:
  - Static: `tests/sandbox_term_env.test.sh`
- 実行コマンド:
  - `bash tests/sandbox_term_env.test.sh`

## 未確定事項（TBD） (必須)
- 該当なし
