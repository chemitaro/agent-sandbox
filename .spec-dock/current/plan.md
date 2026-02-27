---
種別: 実装計画書
機能ID: "CHORE-TUI-COLOR-001"
機能名: "コンテナ内の色数（TERM/COLORTERM）を安定化して Codex CLI の表示崩れを解消"
関連Issue: ["N/A"]
状態: "draft"
作成者: "Codex CLI"
最終更新: "2026-02-26"
依存: ["requirement.md", "design.md"]
---

# CHORE-TUI-COLOR-001 コンテナ内の色数（TERM/COLORTERM）を安定化して Codex CLI の表示崩れを解消 — 実装計画（TDD: Red → Green → Refactor）

## この計画で満たす要件ID (必須)
- 対象AC: AC-001, AC-002, AC-003, AC-004
- 対象EC: EC-001（必要なら）, EC-002（注記のみ）
- 対象制約:
  - `./host/sandbox` 既存フローを壊さない
  - `bash tests/sandbox_cli.test.sh` が成功する

## ステップ一覧（観測可能な振る舞い） (必須)
- [ ] S01: Dockerfile の TERM/COLORTERM をテストで固定する（Red）
- [ ] S02: Dockerfile に TERM/COLORTERM を恒久化しテストを通す（Green/Refactor）
- [ ] S03: 手動受け入れ（compose exec / docker exec -it）を実施し report に残す

### 要件 ↔ ステップ対応表 (必須)
- AC-001 → S02, S03
- AC-002 → S02, S03
- AC-003 → S03
- AC-004 → S01, S02
- EC-001 → S02（必要なら `ncurses-term` 等を追加）
- 非交渉制約 → S02（既存テスト実行で担保）

---

## 実装ステップ（各ステップは“観測可能な振る舞い”を1つ） (必須)

### S01 — Dockerfile の TERM/COLORTERM 恒久化をテストで検査できる (必須)
- 対象: AC-004
- 設計参照:
  - 対象IF: IF-ENV-001（`TERM`/`COLORTERM`）
  - 対象テスト: `tests/sandbox_term_env.test.sh`
- このステップで「追加しないこと（スコープ固定）」:
  - Dockerfile/compose/host の実動作変更（テスト追加のみ）

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に、このステップの作業ステップ（調査/Red/Green/Refactor/品質ゲート/報告/コミット）を登録した
- 登録例:
  - （調査）既存挙動/影響範囲の確認、設計参照の確認
  - （Red）失敗するテストの追加/修正
  - （Green）最小実装
  - （Refactor）整理
  - （品質ゲート）format/lint/test
  - （報告）`.spec-dock/current/report.md` 更新
  - （コミット）このステップの区切りでコミット

#### 期待する振る舞い（テストケース） (必須)
- Given: リポジトリに `Dockerfile` が存在する
- When: `bash tests/sandbox_term_env.test.sh` を実行する
- Then: `Dockerfile` に `TERM`/`COLORTERM` の `ENV` がないため、テストが失敗する（Red）
- 観測点: exit code / stderr
- 追加/更新するテスト: `tests/sandbox_term_env.test.sh`

#### Red（失敗するテストを先に書く） (任意)
- 期待する失敗:
  - ...

#### Green（最小実装） (任意)
- 変更予定ファイル:
  - Add: `<path/...>`
  - Modify: `<path/...>`
- 追加する概念（このステップで導入する最小単位）:
  - ...
- 実装方針（最小で。余計な最適化は禁止）:
  - ...

#### Refactor（振る舞い不変で整理） (任意)
- 目的:
  - ...
- 変更対象:
  - ...

#### ステップ末尾（省略しない） (必須)
- [ ] 期待するテスト（必要ならフォーマット/リンタ）を実行し、成功した
- [ ] `.spec-dock/current/report.md` に実行コマンド/結果/変更ファイルを記録した
- [ ] `update_plan` を更新し、このステップの作業ステップを完了にした
- [ ] コミットした（エージェント）

---

### S02 — コンテナ作成時点で TERM/COLORTERM が恒久化されている（設定が退行しない） (必須)
- 対象: AC-001, AC-002, AC-004, EC-001（必要なら）
- 設計参照:
  - 対象IF: IF-ENV-001（`TERM`/`COLORTERM`）
  - 対象テスト: `tests/sandbox_term_env.test.sh`
- このステップで「追加しないこと（スコープ固定）」:
  - `host/sandbox` の入口補正（今回はやらない）
  - Ghostty terminfo 注入（完全一致は不要）

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に、このステップの作業ステップ（調査/Red/Green/Refactor/品質ゲート/報告/コミット）を登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: `tests/sandbox_term_env.test.sh` が存在する
- When: `Dockerfile` に `ENV TERM=xterm-256color` と `ENV COLORTERM=truecolor` を追加する
- Then: `bash tests/sandbox_term_env.test.sh` が成功する
- 観測点: exit code
- 追加/更新するテスト: `tests/sandbox_term_env.test.sh`

#### ステップ末尾（省略しない） (必須)
- [ ] `bash tests/sandbox_term_env.test.sh` を実行し、成功した
- [ ] `bash tests/sandbox_cli.test.sh` を実行し、成功した
- [ ] `.spec-dock/current/report.md` に実行コマンド/結果/変更ファイルを記録した
- [ ] `update_plan` を更新し、このステップの作業ステップを完了にした
- [ ] コミットした（エージェント）

---

### S03 — 手動受け入れで tput colors=256 を確認できる (必須)
- 対象: AC-001, AC-002, AC-003
- 設計参照:
  - 手動受け入れ手順（design.md の「手動受け入れ」）
- このステップで「追加しないこと（スコープ固定）」:
  - 追加の自動テストや機能追加（必要になった場合は S04 として新規追加）

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に、このステップの作業ステップ（調査/Red/Green/Refactor/品質ゲート/報告/コミット）を登録した

#### 期待する振る舞い（手動受け入れ） (必須)
- Given: `./host/sandbox up` で最新コンテナを起動できる
- When: 以下を実行する
  - `docker compose exec agent-sandbox /bin/zsh -lc 'echo TERM=$TERM; echo COLORTERM=$COLORTERM; tput colors'`
  - `docker exec -it <container> /bin/zsh -lc 'echo TERM=$TERM; echo COLORTERM=$COLORTERM; tput colors'`
  - （任意）コンテナ内で Codex CLI を起動し目視する
- Then:
  - どちらの入口でも `TERM=xterm-256color` / `COLORTERM=truecolor` / `tput colors=256` を満たす
  - Codex CLI の表示崩れが解消している
- 観測点: コマンド出力 / 目視結果

#### ステップ末尾（省略しない） (必須)
- [ ] 手動受け入れ結果を `.spec-dock/current/report.md` に記録した（秘匿情報はマスク）
- [ ] `update_plan` を更新し、このステップの作業ステップを完了にした
- [ ] コミットした（エージェント）

---

## 未確定事項（TBD） (必須)
- 該当なし（requirement.md の Q-001/Q-002 は解消済み）

## 完了条件（Definition of Done） (必須)
- 対象AC/ECがすべて満たされ、テストで保証されている
- MUST NOT / OUT OF SCOPE を破っていない（追加機能を入れていない）
- 品質ゲート（フォーマット/リント/テストのうち該当するもの）が満たされている

## 省略/例外メモ (必須)
- 該当なし
