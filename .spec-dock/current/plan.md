---
種別: 実装計画書
機能ID: "CHORE-ENV-001"
機能名: "Docker/Compose の不要な環境変数整理"
関連Issue: ["N/A"]
状態: "draft"
作成者: "Codex CLI"
最終更新: "2026-01-23"
依存: ["requirement.md", "design.md"]
---

# CHORE-ENV-001 Docker/Compose の不要な環境変数整理 — 実装計画（TDD: Red → Green → Refactor）

## この計画で満たす要件ID (必須)
- 対象AC: AC-001, AC-002
- 対象EC: EC-001, EC-002
- 対象制約: 非交渉制約（既存CLI/テスト互換、マウント先パス不変、認証env varは削除しない）

## ステップ一覧（観測可能な振る舞い） (必須)
- [x] S01: ノイズ env var の退行防止テストを追加する
- [x] S02: `docker-compose.yml` から設定パス系 env var を削除する
- [x] S03: `Dockerfile` から設定パス系 env var を削除する
- [x] S04: `docker-compose.yml` から未使用の `HOST_*`/`PRODUCT_*` を削除する

### 要件 ↔ ステップ対応表 (必須)
- AC-001 → S02, S03, S04
- AC-002 → S01〜S04
- EC-001 → S01（ドキュメント/代替案の明記）、S02〜S04（実装差分）
- EC-002 → S02〜S04（カスタム運用の逃げ道を残す）

---

## 実装ステップ（各ステップは“観測可能な振る舞い”を1つ） (必須)

### S01 — ノイズ env var の退行防止テストを追加する (必須)
- 対象: AC-002 / EC-001
- 設計参照:
  - 対象IF: IF-ENV-001
  - 対象テスト: `tests/sandbox_cli.test.sh`（新規 test を追加）
- このステップで「追加しないこと（スコープ固定）」:
  - Dockerfile/docker-compose の挙動変更（テスト追加のみ）

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に、このステップの作業ステップ（調査/Red/Green/Refactor/品質ゲート/報告/コミット）を登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: `docker-compose.yml` / `Dockerfile` に削除対象 env var が存在する（作業前）
- When: テストを実行する
- Then: “削除対象 env var が存在する”ことを検知できる（Red→Greenで固定する）
- 観測点: テストの exit code / ログ
- 追加/更新するテスト: `tests/sandbox_cli.test.sh::config_env_var_noise_is_not_present`

#### Red（失敗するテストを先に書く） (任意)
- 期待する失敗: 現状のファイルに削除対象が含まれるため、テストが失敗する

#### Green（最小実装） (任意)
- 変更予定ファイル:
  - Modify: `tests/sandbox_cli.test.sh`
- 実装方針:
  - `docker-compose.yml` / `Dockerfile` を grep/rg で検査し、禁止文字列があれば失敗させる

#### Refactor（振る舞い不変で整理） (任意)
- 目的: 検査対象の一覧を読みやすく保つ（配列化/メッセージ整備）

#### ステップ末尾（省略しない） (必須)
- [ ] `bash tests/sandbox_cli.test.sh` を実行し、（このステップ時点では）意図通り Red を確認できた
- [ ] `.spec-dock/current/report.md` に実行コマンド/結果/変更ファイルを記録した
- [ ] `update_plan` を更新し、このステップの作業ステップを完了にした
- [ ] コミットしない（ユーザー指示）

---

### S02 — `docker-compose.yml` から設定パス系 env var を削除する (必須)
- 対象: AC-001 / AC-002 / EC-001 / EC-002
- 設計参照:
  - 対象IF: IF-ENV-001
  - 対象ファイル: `docker-compose.yml`
  - 対象テスト: `tests/sandbox_cli.test.sh::config_env_var_noise_is_not_present`
- このステップで「追加しないこと（スコープ固定）」:
  - `volumes:` のマウント先/元の変更
  - CLI の追加機能

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に、このステップの作業ステップ（調査/Red/Green/Refactor/品質ゲート/報告/コミット）を登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: `docker-compose.yml` の `environment:` に削除対象が存在する
- When: `environment:` から削除対象 env var を削除する
- Then: `docker-compose.yml` に削除対象が存在せず、テスト（S01）が Green になる
- 観測点: テスト結果 / 差分
- 追加/更新するテスト: `tests/sandbox_cli.test.sh::config_env_var_noise_is_not_present`

#### Green（最小実装） (任意)
- 変更予定ファイル:
  - Modify: `docker-compose.yml`
- 実装方針:
  - `environment:` のみから削除する（`volumes:` は残す）

#### ステップ末尾（省略しない） (必須)
- [ ] `bash tests/sandbox_cli.test.sh` を実行し、成功した
- [ ] `.spec-dock/current/report.md` に実行コマンド/結果/変更ファイルを記録した
- [ ] `update_plan` を更新し、このステップの作業ステップを完了にした
- [ ] コミットしない（ユーザー指示）

---

### S03 — `Dockerfile` から設定パス系 env var を削除する (必須)
- 対象: AC-001 / AC-002
- 設計参照:
  - 対象IF: IF-ENV-001
  - 対象ファイル: `Dockerfile`
  - 対象テスト: `tests/sandbox_cli.test.sh::config_env_var_noise_is_not_present`
- このステップで「追加しないこと（スコープ固定）」:
  - 依存追加やインストール手順の変更

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に、このステップの作業ステップ（調査/Red/Green/Refactor/品質ゲート/報告/コミット）を登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: `Dockerfile` に削除対象 `ENV ...` が存在する
- When: `ENV` 行を削除する
- Then: `Dockerfile` に削除対象が存在せず、テスト（S01）が Green のまま維持される
- 観測点: テスト結果 / 差分
- 追加/更新するテスト: `tests/sandbox_cli.test.sh::config_env_var_noise_is_not_present`

#### Green（最小実装） (任意)
- 変更予定ファイル:
  - Modify: `Dockerfile`

#### ステップ末尾（省略しない） (必須)
- [ ] `bash tests/sandbox_cli.test.sh` を実行し、成功した
- [ ] `.spec-dock/current/report.md` に実行コマンド/結果/変更ファイルを記録した
- [ ] `update_plan` を更新し、このステップの作業ステップを完了にした
- [ ] コミットしない（ユーザー指示）

---

### S04 — `docker-compose.yml` から未使用の `HOST_*`/`PRODUCT_*` を削除する (必須)
- 対象: AC-001 / AC-002
- 設計参照:
  - `design.md` の「削除対象（検討: “コンテナに渡す必要がない”）」
- 期待する振る舞い:
  - `docker-compose.yml` の `environment:` から `HOST_*`/`PRODUCT_*` を削除しても、`sandbox` CLI のテストが維持される

---

## 未確定事項（TBD） (必須)
- Q-001:
  - 質問: `docker-compose.yml` の `environment:` から `HOST_*` / `PRODUCT_*` を削除して良いか？
  - 決定: A（削除する）
  - 理由: Compose の補間（`volumes:` / `working_dir:`）には必要だが、コンテナ内で参照箇所が無くノイズだったため
  - 影響範囲: S04 / `docker-compose.yml`
- Q-002:
  - 質問: “設定パス系”以外（`DOCKER_CONFIG`/`DOCKER_HOST`/`DEVCONTAINER`/`TMUX_SESSION_NAME` 等）も同時に整理するか？
  - 決定: A（Dockerfile 側は今回は対象外）
  - 補足: `docker-compose.yml` 側の重複（例: `DEVCONTAINER` / `DOCKER_HOST`）はノイズとして削除した
  - 影響範囲: 追加ステップ化（必要なら別タスク）

## 完了条件（Definition of Done） (必須)
- AC-001/AC-002 が満たされる（ファイル差分とテストで観測できる）
- MUST NOT / OUT OF SCOPE を破っていない
- 品質ゲート（このタスクでは `bash tests/sandbox_cli.test.sh`）が満たされている

## 省略/例外メモ (必須)
- 該当なし
