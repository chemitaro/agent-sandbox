---
種別: 実装計画書
機能ID: "FEAT-006"
機能名: "NPM グローバルツール共有（1回の更新を全コンテナに反映）"
関連Issue: ["TBD"]
状態: "approved"
作成者: "Codex"
最終更新: "2026-01-23"
依存: ["requirement.md", "design.md"]
---

# FEAT-006 NPM グローバルツール共有（1回の更新を全コンテナに反映） — 実装計画（TDD: Red → Green → Refactor）

## この計画で満たす要件ID (必須)
- 対象AC: AC-001, AC-002, AC-003
- 対象EC: EC-001, EC-002
- 対象制約: 既存CLI互換維持 / テストで実Docker禁止 / compose project を跨いで共有

## ステップ一覧（観測可能な振る舞い） (必須)
- [ ] S01: `docker-compose.yml` に固定名の共有 npm volumes を追加する
- [ ] S02: `sandbox tools update` を追加し、1回の手動更新で共有 volume を更新できる
- [ ] S03: `sandbox tools update` の同時実行（競合）を防ぐ（ロック/明確な失敗）
- [ ] S04: （推奨）`Dockerfile` のビルド時 `npm run install-global` を削除し、ビルド時間を削減する

### 要件 ↔ ステップ対応表 (必須)
- AC-001 → S01, S02
- AC-002 → S02
- AC-003 → S02（初回導入手順を提供）
- EC-001 → S03
- EC-002 → S03
- （任意）非交渉制約 → S01, S02（テスト方針/互換維持）

---

## 実装ステップ（各ステップは“観測可能な振る舞い”を1つ） (必須)

### S01 — `docker-compose.yml` に共有 npm volumes を追加する (必須)
- 対象: AC-001（共有の土台）
- 設計参照:
  - 対象IF/API: （なし）
  - 対象テスト: `tests/sandbox_compose_volumes.test.sh::compose_has_shared_npm_volumes`（追加予定）
- このステップで「追加しないこと（スコープ固定）」:
  - `host/sandbox` の新サブコマンド追加（S02でやる）
  - Dockerfile の変更（S04でやる）

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に、このステップの作業ステップ（Red/Green/Refactor/品質ゲート/報告/コミット）を登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: リポジトリの `docker-compose.yml` が存在する
- When: 共有 named volume（固定名）を定義し、サービスにマウントする
- Then: `docker-compose.yml` に “共有 npm-global / npm-cache” の設定が入っている（文字列検証で観測可能）
- 観測点: `tests/sandbox_compose_volumes.test.sh` の grep/検証
- 追加/更新するテスト: `tests/sandbox_compose_volumes.test.sh`

#### Red（失敗するテストを先に書く） (任意)
- 期待する失敗:
  - “共有 volumes の記述が無い” ためテストが落ちる

#### Green（最小実装） (任意)
- 変更予定ファイル:
  - Add: `tests/sandbox_compose_volumes.test.sh`
  - Modify: `docker-compose.yml`
- 実装方針:
  - 固定名（compose project 非依存）の named volume を定義し、`/usr/local/share/npm-global` と NPM cache をマウントする

#### Refactor（振る舞い不変で整理） (任意)
- 目的: compose 設定のコメント/命名を読みやすくする

#### ステップ末尾（省略しない） (必須)
- [ ] テストを実行し成功した（`bash tests/sandbox_compose_volumes.test.sh` 等）
- [ ] `.spec-dock/current/report.md` に実行コマンド/結果/変更ファイルを記録した
- [ ] `update_plan` を更新し、このステップを完了にした
- [ ] コミットした（エージェント）

---

### S02 — `sandbox tools update` で共有 volume を更新できる (必須)
- 対象: AC-001, AC-002, AC-003
- 設計参照:
  - 対象IF/API: IF-001（`sandbox tools update`）
  - 対象テスト: `tests/sandbox_cli.test.sh::tools_update_runs_compose`（追加予定）
- このステップで「追加しないこと（スコープ固定）」:
  - 自動更新（起動時update）を入れない

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に、このステップの作業ステップを登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: ユーザーがホストで `sandbox tools update` を実行する
- When: コマンドが実行される
- Then:
  - `docker compose run --rm --no-deps ...`（更新専用）で `npm run install-global` が実行される
  - `sandbox up/shell` の通常フローでは update が走らない
- 観測点: docker compose スタブログ（`tests/sandbox_cli.test.sh`）
- 追加/更新するテスト:
  - `tests/sandbox_cli.test.sh::tools_update_runs_compose`
  - `tests/sandbox_cli.test.sh::tools_update_does_not_build`

#### Red（失敗するテストを先に書く） (任意)
- 期待する失敗:
  - `sandbox tools update` が未実装で “Not implemented” になる/compose が呼ばれない

#### Green（最小実装） (任意)
- 変更予定ファイル:
  - Modify: `host/sandbox`
  - Modify: `tests/sandbox_cli.test.sh`
- 実装方針:
  - 既存の compose スタブ方針に合わせ、`host/sandbox` に `tools update` 分岐を追加する
  - 更新は “更新専用コンテナ” で行う（`docker compose run --rm --no-deps`）
  - 共有volumeに書き込むため、`--user root` と `--entrypoint /bin/bash` で chown + `npm run install-global` を実行する

#### Refactor（振る舞い不変で整理） (任意)
- 目的: `host/sandbox` のオプション解析と help を読みやすくする

#### ステップ末尾（省略しない） (必須)
- [ ] テストを実行し成功した（`bash tests/sandbox_cli.test.sh`）
- [ ] `.spec-dock/current/report.md` に実行コマンド/結果/変更ファイルを記録した
- [ ] `update_plan` を更新し、このステップを完了にした
- [ ] コミットした（エージェント）

---

### S03 — `sandbox tools update` の同時実行を防ぐ (必須)
- 対象: EC-001, EC-002
- 設計参照:
  - 対象IF/API: IF-001
  - 対象テスト: `tests/sandbox_cli.test.sh::tools_update_locking`（追加予定）
- このステップで「追加しないこと（スコープ固定）」:
  - 分散ロックや複雑な排他（単一ホスト運用なので最小で）

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に、このステップの作業ステップを登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: `sandbox tools update` が同時に実行される
- When: 2つ目が開始する
- Then: 2つ目は待機 or 明確な失敗で終了し、共有 volume の整合性が壊れない
- 観測点: ロックファイル（例: `.agent-home` か `/tmp`）の挙動、終了コード、ログ
- 追加/更新するテスト: `tests/sandbox_cli.test.sh::tools_update_locking`

#### Green（最小実装） (任意)
- 変更予定ファイル:
  - Modify: `host/sandbox`
- 実装方針:
  - ホスト側で簡易ロック（例: `mkdir` を用いたロック）を実装し、update を排他する
  - update 本体（compose 実行）が失敗した場合は非0で返し、ロック解放を保証する

#### ステップ末尾（省略しない） (必須)
- [ ] テストを実行し成功した
- [ ] `.spec-dock/current/report.md` に記録した
- [ ] `update_plan` を更新した
- [ ] コミットした（エージェント）

---

### S04 — （推奨）Dockerfile のビルド時 `npm run install-global` を削除する (必須)
- 対象: “ビルドが遅い” の主因削減（非交渉制約には影響しないが改善）
- 設計参照:
  - 対象IF/API: なし
  - 対象テスト: （必要なら）`npm run verify`（手動）
- このステップで「追加しないこと（スコープ固定）」:
  - 新しいnpmパッケージ管理方式の導入（pnpm/yarn等）

#### update_plan（着手時に登録） (必須)
- [ ] `update_plan` に、このステップの作業ステップを登録した

#### 期待する振る舞い（テストケース） (必須)
- Given: イメージビルド時に `npm run install-global` を実行している
- When: その手順を削除する
- Then: イメージビルドから “CLI導入” を分離でき、更新は `sandbox tools update` に集約される
- 観測点: Dockerfile 差分、（手動）`sandbox tools update` 後に CLI が使えること

#### ステップ末尾（省略しない） (必須)
- [ ] 変更の意図と移行手順を `report.md` に記録した
- [ ] `update_plan` を更新した
- [ ] コミットした（エージェント）

---

## 未確定事項（TBD） (必須)
- Q-001:
  - 質問: 初回bootstrapを自動化するか？
  - 選択肢:
    - A: 初回のみ自動bootstrap（不足検知→更新）
    - B: 初回も手動update（誘導だけ）
  - 推奨案（暫定）: B（シンプル優先）
  - 影響範囲: S02/S03（追加実装/テストが必要）
- Q-002:
  - 質問: `sandbox build` デフォルトの見直しを今回やるか？
  - 選択肢:
    - A: 別チケットに分離
    - B: 今回一緒にやる
  - 推奨案（暫定）: A
  - 影響範囲: `host/sandbox` と既存テスト

## 完了条件（Definition of Done） (必須)
- 対象AC/ECがすべて満たされ、テストで保証されている
- MUST NOT / OUT OF SCOPE を破っていない（追加機能を入れていない）
- 品質ゲート（テスト）が満たされている

## 省略/例外メモ (必須)
- 該当なし
