---
種別: 実装報告書
機能ID: "CHORE-NODE-LTS-001"
機能名: "Docker イメージで導入する Node.js を 20 系固定から Active LTS へ更新"
関連Issue: ["N/A"]
状態: "draft"
作成者: "Codex CLI"
最終更新: "2026-03-07"
依存: ["requirement.md", "design.md", "plan.md"]
---

# CHORE-NODE-LTS-001 Docker イメージで導入する Node.js を 20 系固定から Active LTS へ更新 — 実装報告（LOG）

## 実装サマリー (任意)
- 2026-03-07 時点の最新安定版解釈を `Active LTS (24.x)` に固定した。
- 実装前に Dockerfile の現状、`package.json` の整合、Node.js/NodeSource の一次情報を確認した。
- `Dockerfile` の Node.js 導入を 24 系へ更新し、Node 系列テストを追加、既存 CLI テストの Linux 依存を最小修正した。

## 実装記録（セッションログ） (必須)

### 2026-03-07 15:30 - 16:05 UTC（計画/調査/契約固定）

#### 対象
- Step: 計画フェーズ、S01-S03 の準備
- AC/EC: AC-001, AC-002, AC-003, EC-001, EC-002

#### 実施内容
- `Dockerfile` の Node.js 導入箇所と `package.json` の `engines` を確認した。
- Node.js 公式リリース情報と NodeSource 配布スクリプトを確認し、2026-03-07 時点で `24.x = Active LTS`, `25.x = Current` であることを根拠化した。
- `.spec-dock/current/requirement.md` / `design.md` / `plan.md` を今回タスク向けに更新し、実装契約を固定した。

#### 実行コマンド / 結果
```bash
rg -n "setup_20\\.x|setup_[0-9]+\\.x|setup_lts|setup_current|engines" Dockerfile package.json -S
# Dockerfile に setup_20.x、package.json に node >=20.0.0 を確認

nl -ba Dockerfile | sed -n '1,40p'
# 11-14 行付近で Node.js 20 固定のコメントと setup_20.x を確認

date -u '+%Y-%m-%d %H:%M UTC'
# 2026-03-06 15:49 UTC
```

#### 変更したファイル
- `.spec-dock/current/requirement.md` - Node.js 更新タスクの要件定義へ差し替え
- `.spec-dock/current/design.md` - Active LTS 採用理由と変更設計を記載
- `.spec-dock/current/plan.md` - 実装・検証ステップを定義
- `.spec-dock/current/report.md` - 調査ログを記録
- `.spec-dock/current/discussions/node-release-channel.md` - リリースチャネル判断の補助資料

#### コミット
- N/A（未コミット）

---

### 2026-03-07 16:20 - 16:30 UTC（フォローアップ修正）

#### 対象
- Step: S02
- AC/EC: AC-003

#### 実施内容
- `host/sandbox` の `ensure_tmux_available` を補強し、`command -v tmux` は通るが実行不可（exit 127）の場合も `tmux command not found` を返すようにした。
- 既存の `tests/sandbox_cli.test.sh` / `tests/sandbox_node_version.test.sh` を再実行して成功を確認した。

#### 実行コマンド / 結果
```bash
bash tests/sandbox_cli.test.sh
# 成功（exit code 0）

bash tests/sandbox_node_version.test.sh
# 成功（exit code 0）
```

#### 変更したファイル
- `host/sandbox` - `ensure_tmux_available` の実行可能性チェックを追加
- `.spec-dock/current/report.md` - フォローアップ修正ログを追記

#### コミット
- N/A（未コミット）

#### メモ
- ユーザー確認により、「最新安定版」は `Current` ではなく `Active LTS` として扱う。
- 再現性優先のため `setup_lts.x` ではなく `setup_24.x` を採用する。

---

### 2026-03-07 16:05 - 16:12 UTC（実装/検証）

#### 対象
- Step: S01, S02, S03
- AC/EC: AC-001, AC-002, AC-003, EC-001, EC-002

#### 実施内容
- `Dockerfile` の NodeSource セットアップを `setup_20.x` から `setup_24.x` に更新した。
- `tests/sandbox_node_version.test.sh` を追加し、24 系固定と 20 系残存なしを静的検査できるようにした。
- `host/sandbox` の `tmux` 不在判定を補強し、既存エラーメッセージを保ったままテスト可能にした。
- `tests/sandbox_cli.test.sh` の既存環境依存を最小修正し、Linux 環境でも docker 不在/TZ ケースが安定するようにした。
- `./host/sandbox up` でイメージを再ビルドし、起動済みコンテナで `node --version` を確認した。

#### 実行コマンド / 結果
```bash
bash tests/sandbox_node_version.test.sh
# ==> dockerfile_uses_nodesource_setup_24
# ==> dockerfile_does_not_use_nodesource_setup_20

bash tests/sandbox_cli.test.sh
# 全テスト成功（exit code 0）

./host/sandbox up
# Docker イメージ build / container start 成功

docker exec sandbox-box-f380f223dbca node --version
# v24.14.0
```

#### 変更したファイル
- `Dockerfile` - NodeSource セットアップを 24 系へ更新
- `host/sandbox` - `tmux` 不在判定を環境依存なく補強
- `tests/sandbox_node_version.test.sh` - Node.js 系列の静的検査テストを追加
- `tests/sandbox_cli.test.sh` - docker 不在/TZ 注入ケースの環境依存を最小修正
- `.spec-dock/current/design.md` - 実際の変更計画と検証手順へ同期
- `.spec-dock/current/plan.md` - S01-S03 完了を反映
- `.spec-dock/current/report.md` - 実装ログを追記

#### コミット
- N/A（未コミット）

#### メモ
- `tests/sandbox_cli.test.sh` の失敗は Node 24 化そのものではなく、Linux 環境での既存テスト前提の揺れだった。
- runtime 確認は `docker exec` で `v24.14.0` を観測した。

---

## 遭遇した問題と解決 (任意)
- 問題: 「最新安定版」が `Current` か `Active LTS` かで解釈が分かれうる
  - 解決: Node.js 公式の production 推奨を根拠に `Active LTS` として固定した
- 問題: `tests/sandbox_cli.test.sh` が Linux 環境で ambient `TZ` と `docker` 解決結果に依存していた
  - 解決: テスト側で前提を明示し、既存期待値を保ったまま安定化した

## 学んだこと (任意)
- `package.json` の `engines.node >=20.0.0` は 24 系への更新を妨げない
- NodeSource の可変エイリアスは便利だが、再現性を優先する今回の要件とは相性がよくない

## 今後の推奨事項 (任意)
- 必要なら別タスクで `npm run verify` を実行し、CLI 群の Node.js 24 系互換を確認する

## 省略/例外メモ (必須)
- 該当なし

### 2026-03-06 16:05 - 16:10 UTC（実装/テスト/受け入れ確認）

#### 対象
- Step: S01, S02, S03
- AC/EC: AC-001, AC-002, AC-003, EC-001, EC-002

#### 実施内容
- `Dockerfile` の NodeSource セットアップを `setup_20.x` から `setup_24.x` へ更新した。
- Node.js 系列の退行防止テスト `tests/sandbox_node_version.test.sh` を追加した。
- `tests/sandbox_cli.test.sh` の `tz_injection_rules` がホスト `TZ` 継承で不安定になる問題を最小修正し、Case B/C を `env -u TZ` で実行するよう更新した。
- 同ファイルの `path_without_docker` を環境依存回避（docker shim）へ更新した。
- 同ファイルの `codex_errors_when_tmux_missing` を環境依存回避のため最小修正した（`tmux` のみ未解決になる PATH をテスト内で構成）。
- Docker イメージを再ビルドし、`node --version` が `v24.` 系であることを確認した。

#### 実行コマンド / 結果
```bash
bash tests/sandbox_node_version.test.sh
# 初回: 失敗（Expected Dockerfile to contain setup_24.x）
# 変更後: 成功

bash tests/sandbox_cli.test.sh
# 途中: tz_injection_rules / codex_errors_when_tmux_missing で環境依存失敗を確認
# 修正後: 成功

docker build -t sandbox-node24-check --build-arg TZ=Asia/Tokyo --build-arg PRODUCT_NAME=mount .
# 成功

docker run --rm --entrypoint node sandbox-node24-check --version
# v24.14.0
```

#### 変更したファイル
- `Dockerfile` - Node.js 導入系列を `setup_24.x` へ更新
- `tests/sandbox_node_version.test.sh` - Node.js 系列の退行防止テストを追加
- `tests/sandbox_cli.test.sh` - 環境依存で不安定だった `tz_injection_rules` / `codex_errors_when_tmux_missing` を最小修正
- `.spec-dock/current/report.md` - 実装/検証ログを追記

#### コミット
- N/A（未コミット）
