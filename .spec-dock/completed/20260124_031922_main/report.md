---
種別: 実装報告書
機能ID: "CHORE-ENV-001"
機能名: "Docker/Compose の不要な環境変数整理"
関連Issue: ["N/A"]
状態: "draft"
作成者: "Codex CLI"
最終更新: "2026-01-23"
依存: ["requirement.md", "design.md", "plan.md"]
---

# CHORE-ENV-001 Docker/Compose の不要な環境変数整理 — 実装報告（LOG）

## 実装サマリー (任意)
- Dockerfile / docker-compose.yml の「設定パス系・未使用・重複」env var を削除し、設定の永続化は bind mount + 各CLIのデフォルト参照に統一した。
- 退行防止として、禁止 env var がファイル内に存在しないことを検査するテストを追加した。

## 実装記録（セッションログ） (必須)

### 2026-01-23（時間: 記録なし）

#### 対象
- Step: S01, S02, S03, S04
- AC/EC: AC-001, AC-002 / EC-001, EC-002

#### 実施内容
- S01: `tests/sandbox_cli.test.sh` に `config_env_var_noise_is_not_present` を追加し、ノイズ env var の再導入を検知できるようにした（最初は意図通り失敗することを確認）。
- S02: `docker-compose.yml` の `environment:` から設定パス系 env var を削除した。
- S03: `Dockerfile` から設定パス系 env var を削除した。
- S04: `docker-compose.yml` の `environment:` から未使用/重複の env var（`HOST_*`/`PRODUCT_*`、`DEVCONTAINER`、`DOCKER_HOST`）を削除し、テストの検査対象にも追加した。

#### 実行コマンド / 結果
```bash
bash tests/sandbox_cli.test.sh

# 初回: config_env_var_noise_is_not_present が意図通り失敗（Red）
# 修正後: 全テスト成功（Green）
```

#### 変更したファイル
- `tests/sandbox_cli.test.sh` - 禁止 env var のファイル検査テストを追加/拡張
- `docker-compose.yml` - `environment:` からノイズ env var を削除
- `Dockerfile` - 設定パス系 `ENV ...` を削除
- `.spec-dock/current/requirement.md` - TBD を解消（決定を反映）
- `.spec-dock/current/design.md` - 設計の決定を反映
- `.spec-dock/current/plan.md` - 実施済みとして更新、コミット非実施を明記

#### コミット
- なし（ユーザー指示により `git commit` は実施しない）

#### メモ
- 設定の永続化は `.agent-home/` の bind mount が正であり、パスを env var で固定しなくても成立する。

## 省略/例外メモ (必須)
- 該当なし
