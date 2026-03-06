---
種別: 実装計画書
機能ID: "CHORE-NODE-LTS-001"
機能名: "Docker イメージで導入する Node.js を 20 系固定から Active LTS へ更新"
関連Issue: ["N/A"]
状態: "draft"
作成者: "Codex CLI"
最終更新: "2026-03-07"
依存: ["requirement.md", "design.md"]
---

# CHORE-NODE-LTS-001 Docker イメージで導入する Node.js を 20 系固定から Active LTS へ更新 — 実装計画（TDD: Red → Green → Refactor）

## この計画で満たす要件ID (必須)
- 対象AC: AC-001, AC-002, AC-003
- 対象EC: EC-001, EC-002
- 対象制約:
  - `Current` 系へは上げない
  - Docker ベース開発フローを壊さない

## ステップ一覧（観測可能な振る舞い） (必須)
- [x] S01: Dockerfile の Node.js 系列を静的検査できる
- [x] S02: Docker イメージが Node.js 24 系を導入する
- [x] S03: 再ビルド後の runtime 検証結果を report に残す

### 要件 ↔ ステップ対応表 (必須)
- AC-001 → S01, S02
- AC-002 → S02, S03
- AC-003 → S01, S02
- EC-001 → S02
- EC-002 → S02

---

## 実装ステップ（各ステップは“観測可能な振る舞い”を1つ） (必須)

### S01 — Dockerfile の Node.js 系列をテストで固定できる (必須)
- 対象: AC-001, AC-003
- 設計参照:
  - 対象IF/API: IF-ENV-001
  - 対象テスト: `tests/sandbox_node_version.test.sh`
- このステップで「追加しないこと（スコープ固定）」:
  - Dockerfile の本実装変更以外の設定追加

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に、このステップの作業ステップ（調査/Red/Green/Refactor/品質ゲート/報告/コミット）を登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: リポジトリに `Dockerfile` が存在する
- When: `bash tests/sandbox_node_version.test.sh` を実行する
- Then: 20 系固定の現状では失敗し、24 系への更新後は成功する
- 観測点（UI/HTTP/DB/Log など）: exit code / stderr
- 追加/更新するテスト: `tests/sandbox_node_version.test.sh`

#### ステップ末尾（省略しない） (必須)
- [x] `bash tests/sandbox_node_version.test.sh` を実行し、成功した
- [x] `.spec-dock/current/report.md` に実行コマンド/結果/変更ファイルを記録した
- [x] `update_plan` を更新し、このステップの作業ステップを完了にした
- [ ] コミットした（エージェント）

---

### S02 — Docker イメージが Node.js 24 系を導入する (必須)
- 対象: AC-001, AC-002, AC-003, EC-001, EC-002
- 設計参照:
  - 対象IF/API: IF-ENV-001
  - 対象テスト: `tests/sandbox_node_version.test.sh`, `tests/sandbox_cli.test.sh`
- このステップで「追加しないこと（スコープ固定）」:
  - `package.json` の依存変更
  - `host/sandbox` や Compose 設定の変更

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に、このステップの作業ステップ（調査/Red/Green/Refactor/品質ゲート/報告/コミット）を登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: Node.js 系列の静的検査テストが存在する
- When: `Dockerfile` の NodeSource セットアップを `setup_24.x` に更新する
- Then:
  - `bash tests/sandbox_node_version.test.sh` が成功する
  - `bash tests/sandbox_cli.test.sh` が成功する
- 観測点（UI/HTTP/DB/Log など）: exit code / テストログ
- 追加/更新するテスト: `tests/sandbox_node_version.test.sh`

#### ステップ末尾（省略しない） (必須)
- [x] `bash tests/sandbox_node_version.test.sh` を実行し、成功した
- [x] `bash tests/sandbox_cli.test.sh` を実行し、成功した
- [x] `.spec-dock/current/report.md` に実行コマンド/結果/変更ファイルを記録した
- [x] `update_plan` を更新し、このステップの作業ステップを完了にした
- [ ] コミットした（エージェント）

---

### S03 — 再ビルド後に `node --version` が `v24.` 系になることを確認できる (必須)
- 対象: AC-002
- 設計参照:
  - 手動受け入れ手順（design.md のテスト戦略）
- このステップで「追加しないこと（スコープ固定）」:
  - 追加の機能変更

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に、このステップの作業ステップ（調査/Red/Green/Refactor/品質ゲート/報告/コミット）を登録した

#### 期待する振る舞い（手動受け入れ） (必須)
- Given: 更新後のイメージを再ビルドできる
- When: コンテナ内で `node --version` を実行する
- Then: `v24.` 系で始まる
- 観測点（UI/HTTP/DB/Log など）: コマンド出力

#### ステップ末尾（省略しない） (必須)
- [x] 手動受け入れ結果を `.spec-dock/current/report.md` に記録した
- [x] `update_plan` を更新し、このステップの作業ステップを完了にした
- [ ] コミットした（エージェント）

---

## 未確定事項（TBD） (必須)
- 該当なし

## 完了条件（Definition of Done） (必須)
- 対象 AC/EC がすべて満たされる
- Node.js 導入系列が 24 系固定になり、既存テストを通過する
- 変更内容と検証結果が report に記録される

## 省略/例外メモ (必須)
- 該当なし
