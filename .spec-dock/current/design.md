---
種別: 設計書
機能ID: "FEAT-006"
機能名: "NPM グローバルツール共有（1回の更新を全コンテナに反映）"
関連Issue: ["TBD"]
状態: "approved"
作成者: "Codex"
最終更新: "2026-01-23"
依存: ["requirement.md"]
---

# FEAT-006 NPM グローバルツール共有（1回の更新を全コンテナに反映） — 設計（HOW）

## 目的・制約（要件から転記・圧縮） (必須)
- 目的: NPM グローバルCLI（codex/claude/gemini/opencode 等）を、ホスト上で1回更新するだけで全 sandbox コンテナに反映する。
- MUST:
  - `/usr/local/share/npm-global` を全 compose project で共有する。
  - “手動更新” の導線（`sandbox tools update`）を提供する。
- MUST NOT:
  - 起動のたびに自動で更新する（更新は手動）
  - テストで実Dockerを呼ぶ（スタブで検証）
- 非交渉制約:
  - 既存 `sandbox` サブコマンド互換を維持する（追加はOK、破壊はNG）
  - compose project を跨いで共有できること（固定名）
- 前提:
  - 更新対象は `package.json` の `install-global` で導入するCLI群

---

## 既存実装/規約の調査結果（As-Is / 95%理解） (必須)
- 参照した規約/実装（根拠）:
  - `AGENTS.md`: 会話言語、Bash方針、テスト方針、禁止Git操作
  - `docker-compose.yml`: `.agent-home` を中心に永続化しているが NPM グローバルは対象外 (`docker-compose.yml`:35-50)
  - `Dockerfile`: `NPM_CONFIG_PREFIX` とビルド時 `npm run install-global` (`Dockerfile`:118-127)
  - `package.json`: `install-global` が CLI 群を `npm install -g` する (`package.json`:18)
  - `tests/sandbox_cli.test.sh`: docker/compose をスタブ化してコマンド列を検証する
- 観測した現状（事実）:
  - 現状は “イメージビルド” に CLI 更新が内包されるため、更新コストが高く、複数コンテナ運用で冗長になりやすい。
- 採用するパターン:
  - 固定名の Docker named volume を使い、compose project を跨いで共有する。
  - 更新はホスト側コマンドから “更新専用コンテナ（`docker compose run --rm`）” で実行する。
- 採用しない/変更しない（理由）:
  - 起動時の自動更新はしない（手動更新に集約）
  - 既存サブコマンドの挙動変更はしない
- 影響範囲:
  - `docker-compose.yml`, `host/sandbox`, `tests/*`
  - （推奨）`Dockerfile` のビルド時 NPM グローバル導入を削除してビルドを軽くする

## 主要フロー（テキスト：AC単位で短く） (任意)
- Flow for AC-001（更新の共有）:
  1) ユーザーが `sandbox tools update` を実行する
  2) 共有 named volume に NPM グローバルCLIをインストール/更新する
  3) 他の sandbox コンテナは同じ volume を参照して更新結果を利用する
- Flow for AC-002（通常起動）:
  1) ユーザーが `sandbox up` / `sandbox shell` を実行する
  2) 自動更新は走らず、共有 volume 上のCLIをそのまま使う

## データ・バリデーション（必要最小限） (任意)
- 該当なし

## 判断材料/トレードオフ（Decision / Trade-offs） (任意)
- 論点: 共有方式（requirement Q-001）
  - A: 固定名の named volume（推奨）
  - B: ホスト bind mount（`.agent-home/npm-global` 等）
  - 決定（推奨）: A
  - 理由: compose project を跨いで確実に共有でき、macOSでもI/O性能が出やすい
- 論点: 更新の実行場所
  - A: 更新専用（`docker compose run --rm`）（推奨）
  - B: 起動済みコンテナに `docker compose exec`
  - 決定（推奨）: A
  - 理由: “どのコンテナに入るか” をユーザーに委ねない
- 論点: Dockerfile のビルド時 `npm run install-global`
  - A: 維持（ただし volume により実体が隠れ、ビルド時間だけが残る）
  - B: 削除（推奨）
  - 決定（推奨）: B
  - 理由: ビルドの待ち時間を減らし、更新を手動コマンドへ集約できる

## インターフェース契約（ここで固定） (任意)
### API（ある場合）
- 該当なし

### 関数・クラス境界（重要なものだけ）
- IF-001: `sandbox tools update`（`host/sandbox` のサブコマンド）
  - Input: `sandbox tools update [--mount-root <path>] [--workdir <path>]`
  - Output: 終了コード 0（成功）/ 非0（失敗）。失敗時は stderr に理由を出す。
  - Side effects: 共有 named volume の NPM グローバルCLIが更新される。
  - 実装方針: `docker compose run --rm --no-deps ...` で `npm run install-global` を実行する。

## 変更計画（ファイルパス単位） (必須)
- 追加（Add）:
  - （任意）`tests/sandbox_compose_volumes.test.sh`: `docker-compose.yml` の静的検証（共有volumesが設定されていること）
- 変更（Modify）:
  - `docker-compose.yml`: 固定名 named volume 定義と、`/usr/local/share/npm-global`/NPM cache のマウント追加
  - `host/sandbox`: `tools update` サブコマンドとヘルプ追加
  - `tests/sandbox_cli.test.sh`: `tools update` の呼び出し検証を追加
  - （推奨）`Dockerfile`: ビルド時の `npm run install-global` を削除
- 削除（Delete）:
  - 該当なし
- 移動/リネーム（Move/Rename）:
  - 該当なし
- 参照（Read only / context）:
  - `package.json`, `.npmrc`

## マッピング（要件 → 設計） (必須)
- AC-001 → `docker-compose.yml`（共有ボリューム）, IF-001（tools update）
- AC-002 → IF-001（手動更新のみ）, `host/sandbox`（通常起動パスはupdateしない）
- AC-003 → 初回導入手順（`sandbox tools update` を案内）
- EC-001/EC-002 → `host/sandbox`（updateの排他/失敗時の扱い）

## テスト戦略（最低限ここまで具体化） (任意)
- 追加/更新するテスト:
  - Bash: `tests/sandbox_cli.test.sh`
  - （任意）Bash: `tests/sandbox_compose_volumes.test.sh`
- どのAC/ECをどのテストで保証するか:
  - AC-001 → `tests/sandbox_cli.test.sh::tools_update_runs_compose`
  - AC-002 → `tests/sandbox_cli.test.sh::tools_update_does_not_build`
  - （任意）AC-001/003 → `tests/sandbox_compose_volumes.test.sh::compose_has_shared_npm_volumes`
  - EC-001 → `tests/sandbox_cli.test.sh::tools_update_locking`（ロックを入れる場合）
- 非交渉制約の検証:
  - 実Dockerを呼ばない → docker/compose スタブログで検証
- 実行コマンド:
  - `bash tests/sandbox_cli.test.sh`

## リスク/懸念（Risks） (任意)
- R-001: 初回は共有ボリュームが空 → `sandbox tools update` を “最初に1回” 実行する導線が必要
- R-002: 同時更新 → update 実装に簡易ロックが必要（EC-001）

## 未確定事項（TBD） (必須)
- Q-001:
  - 質問: 初回bootstrapを自動化するか？
  - 選択肢:
    - A: 初回のみ自動bootstrap（起動時に不足検知→更新）
    - B: 初回も手動update（ドキュメント誘導）
  - 推奨案（暫定）: B（シンプル優先。必要ならAを追加）
  - 影響範囲: `host/sandbox`/運用手順/テスト
- Q-002:
  - 質問: `sandbox build` のデフォルト（キャッシュ）を今回触るか？
  - 選択肢:
    - A: 触らない（別チケット）
    - B: 今回一緒に戻す
  - 推奨案（暫定）: A（スコープを分ける）
  - 影響範囲: `host/sandbox` の既存挙動
