---
種別: 実装計画書
機能ID: "fix-fzf-plugin-startup"
機能名: "zsh startup から fzf plugin を外して shell 初期化エラーを防ぐ"
関連Issue: ["user-request-2026-03-11-fzf-plugin"]
状態: "approved"
作成者: "Codex"
最終更新: "2026-03-11"
依存: ["requirement.md", "design.md"]
---

# fix-fzf-plugin-startup — 実装計画

## この計画で満たす要件ID (必須)
- 対象AC: AC-001, AC-002
- 対象EC: EC-001

## ステップ一覧（観測可能な振る舞い） (必須)
- [x] S01: `Dockerfile` から `-p fzf` を除去する
- [x] S02: 静的テストで `fzf plugin` 不使用を検証する
- [x] S03: 対象テストを実行して結果を記録する

### 要件 ↔ ステップ対応表 (必須)
- AC-001 → S01
- AC-002 → S02, S03
- EC-001 → S01

## 完了条件（Definition of Done） (必須)
- `Dockerfile` の plugin 指定から `fzf` が外れている
- 対象テストが成功する

## 省略/例外メモ (必須)
- 小規模変更のため 1 ステップで実装と検証を行う
