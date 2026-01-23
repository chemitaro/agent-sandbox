---
種別: 実装報告書
機能ID: "FEAT-006"
機能名: "NPM グローバルツール共有（1回の更新を全コンテナに反映）"
関連Issue: ["TBD"]
状態: "draft"
作成者: "Codex"
最終更新: "2026-01-23"
依存: ["requirement.md", "design.md", "plan.md"]
---

# FEAT-006 NPM グローバルツール共有（1回の更新を全コンテナに反映） — 実装報告（LOG）

## 実装サマリー (任意)
- 2026-01-23 時点では計画フェーズ（要件/設計/実装計画）のみ実施。コード変更は未着手。

## 実装記録（セッションログ） (必須)

### 2026-01-23 22:00 - 22:10

#### 対象
- Step: （Planning Phase）
- AC/EC: AC-001, AC-002, AC-003 / EC-001, EC-002

#### 実施内容
- `.spec-dock/current/requirement.md`, `.spec-dock/current/design.md`, `.spec-dock/current/plan.md` を作成（ドラフト）
- 共有方式（固定名 named volume + 手動更新コマンド）を推奨案として整理

#### 実行コマンド / 結果
```bash
sed -n '1,200p' .spec-dock/docs/spec-dock-guide.md
rg -n "install-global|NPM_CONFIG_PREFIX|npm run install-global" Dockerfile package.json docker-compose.yml scripts/docker-entrypoint.sh host/sandbox
nl -ba Dockerfile | sed -n '100,150p'
nl -ba docker-compose.yml | sed -n '1,120p'

OK
```

#### 変更したファイル
- `.spec-dock/current/requirement.md` - FEAT-006 の要件ドラフトを作成
- `.spec-dock/current/design.md` - FEAT-006 の設計ドラフトを作成
- `.spec-dock/current/plan.md` - FEAT-006 の実装計画ドラフトを作成
- `.spec-dock/current/report.md` - 本ログを作成

#### コミット
- 該当なし（未実装）

#### メモ
- 次はユーザー承認（`approved`）取得後に実装へ移行する。

---

### 2026-01-23 22:10 - 22:13

#### 対象
- Step: S01
- AC/EC: AC-001

#### 実施内容
- `docker-compose.yml` に固定名の共有 npm volumes（npm-global / npm-cache）を追加
- 追加した設定を静的に検証するテストを追加

#### 実行コマンド / 結果
```bash
bash tests/sandbox_compose_volumes.test.sh

==> compose_has_shared_npm_volumes
```

#### 変更したファイル
- `docker-compose.yml` - 共有 named volume の定義とマウントを追加
- `tests/sandbox_compose_volumes.test.sh` - compose の静的検証テストを追加

#### コミット
- 該当なし（AGENTS.md の禁止操作により `git commit` は実施しない）

#### メモ
- 共有方式は固定名 named volume を採用（compose project を跨いで共有できる）。

---

### 2026-01-23 22:13 - 22:18

#### 対象
- Step: S02
- AC/EC: AC-001, AC-002, AC-003

#### 実施内容
- `sandbox tools update` を実装（更新専用コンテナで `npm run install-global` を実行）
- docker compose スタブテストを追加し、`docker compose run` が呼ばれることを検証

#### 実行コマンド / 結果
```bash
bash tests/sandbox_cli.test.sh

(all tests passed)
```

#### 変更したファイル
- `host/sandbox` - `tools update` サブコマンドとヘルプを追加
- `tests/sandbox_cli.test.sh` - `tools_update_runs_compose` テストを追加

#### コミット
- 該当なし（AGENTS.md の禁止操作により `git commit` は実施しない）

#### メモ
- 更新は “手動コマンド” のみに集約し、通常の `up/shell` では自動更新しない方針を維持。

---

### 2026-01-23 22:18 - 22:21

#### 対象
- Step: S03
- AC/EC: EC-001, EC-002

#### 実施内容
- `sandbox tools update` の同時実行を防ぐための簡易ロックを追加（既存ロックがある場合は明確に失敗）
- ロック時に docker compose が呼ばれないことをテストで検証

#### 実行コマンド / 結果
```bash
bash tests/sandbox_cli.test.sh

(all tests passed)
```

#### 変更したファイル
- `host/sandbox` - `SANDBOX_TOOLS_UPDATE_LOCK_DIR` を使ったロックを追加
- `tests/sandbox_cli.test.sh` - `tools_update_locking` テストを追加

#### コミット
- 該当なし（AGENTS.md の禁止操作により `git commit` は実施しない）

#### メモ
- ロックは “待機” ではなく “明確な失敗” を採用（簡易・安全優先）。

---

### 2026-01-23 22:21 - 22:22

#### 対象
- Step: S04
- AC/EC: （非機能改善）

#### 実施内容
- `Dockerfile` からビルド時の `npm run install-global` を削除し、イメージビルドの負荷を軽減
- 代わりに `sandbox tools update` を “更新の唯一の導線” とする前提を強化

#### 実行コマンド / 結果
```bash
(no command)
```

#### 変更したファイル
- `Dockerfile` - ビルド時 NPM グローバル導入を削除し、npm cache ディレクトリ作成のみ残す

#### コミット
- 該当なし（AGENTS.md の禁止操作により `git commit` は実施しない）

#### メモ
- 初回は `sandbox tools update` を実行して共有ボリュームへ導入する前提になる。

---

### 2026-01-23 22:22 - 22:23

#### 対象
- Step: （品質ゲート）
- AC/EC: AC-001, AC-002, AC-003 / EC-001, EC-002

#### 実施内容
- 変更範囲のテスト一式を実行し、成功を確認

#### 実行コマンド / 結果
```bash
for f in tests/*.test.sh; do echo "Running $f"; bash "$f"; done

OK
```

#### 変更したファイル
- 該当なし（テスト実行のみ）

#### コミット
- 該当なし（AGENTS.md の禁止操作により `git commit` は実施しない）

#### メモ
- `tools update` はネットワークを使うため、実環境ではプロキシ/Firewall設定の影響を受ける可能性がある。

---

## 遭遇した問題と解決 (任意)
- 該当なし

## 学んだこと (任意)
- 該当なし

## 今後の推奨事項 (任意)
- `sandbox tools update` を「更新の唯一の導線」として運用し、通常の `up/shell` は高速のまま維持する。

## 省略/例外メモ (必須)
- 該当なし
