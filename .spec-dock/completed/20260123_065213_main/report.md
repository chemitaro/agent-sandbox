---
種別: 実装報告書
機能ID: "GC-001"
機能名: "未使用ファイルの棚卸しと削除"
関連Issue: ["TBD"]
状態: "draft"
作成者: "Codex"
最終更新: "2026-01-23"
依存: ["requirement.md", "design.md", "plan.md"]
---

# GC-001 未使用ファイルの棚卸しと削除 — 実装報告（LOG）

## 実装サマリー (任意)
- 未使用ファイルの削除/リネームと `.env.example` の文言更新を実施。
- `Makefile` を `install` / `help` のみに整理し、古いヘルプ情報を削除。
- `.gitignore` から廃止ファイルのエントリを削除。
- テスト不備を修正し、`tests/*.sh` がすべて成功することを確認。
- `CHANGELOG.md` / `CLAUDE.md` / `README.md` / `.devcontainer/` を削除（README は後で作り直す前提）。

## 実装記録（セッションログ） (必須)

### 2026-01-23 12:10 - 12:27

#### 対象
- Step: S01, S02
- AC/EC: AC-001, AC-002, AC-003 / EC-001, EC-002

#### 実施内容
- 参照調査を実施し、未使用ファイルを削除/リネーム。
- `.env.example` を `.env` 向けの説明に更新。
- `Makefile` を公開コマンドのみ残す形に整理。
- `.gitignore` から廃止対象の記述を削除。

#### 実行コマンド / 結果
```bash
rg -n "sandbox\.config" .
rg -n "docker-compose\.git-ro\.yml" .
rg -n "generate-git-ro-overrides" .
rg -n "get-tmux-session\.sh" .
rg -n "product/|product\." .
rg -n "\.env\.example|env\.example" .

mv sandbox.config.example .env.example
rm sandbox.config docker-compose.git-ro.yml scripts/generate-git-ro-overrides.sh scripts/get-tmux-session.sh product/.keep
rmdir product

# .env.example / Makefile / .gitignore / spec-dock docs を更新

bash tests/sandbox_cli.test.sh
# 結果: codex_inner_runs_codex_resume_and_returns_to_zsh で失敗
# Expected log to contain: exec /bin/zsh
```

#### 変更したファイル
- `Makefile` - 公開コマンド整理とヘルプ更新
- `.env.example` - 旧 sandbox.config 記述を .env 向けに更新
- `.gitignore` - 廃止対象の ignore を削除
- `.spec-dock/current/requirement.md` - スコープ/As-Is の更新
- `.spec-dock/current/design.md` - 変更計画と観測情報の更新
- `.spec-dock/current/plan.md` - 実装計画の更新
- `.spec-dock/current/discussions/garbage-files.md` - 棚卸し結果の更新

#### 変更・削除したファイル
- 削除: `sandbox.config`, `docker-compose.git-ro.yml`, `scripts/generate-git-ro-overrides.sh`, `scripts/get-tmux-session.sh`, `product/.keep`
- リネーム: `sandbox.config.example` → `.env.example`
- 削除: `product/`（空ディレクトリのため）

#### コミット
- 実施せず（禁止操作のため）

#### メモ
- `tests/sandbox_cli.test.sh` が 1 件失敗しているため、後続セッションで修正対応

---

### 2026-01-23 12:27 - 12:43

#### 対象
- Step: S01, S02
- AC/EC: AC-003

#### 実施内容
- `tests/sandbox_cli.test.sh` の失敗原因を調査し、テスト側を修正。
  - ログは `printf '%q'` により `exec\ /bin/zsh` のようにエスケープされるため、期待値を修正
  - `--workdir` のように `-` 始まりの期待値が `grep` のオプション扱いにならないよう、`grep ... -- "$expected"` に修正
- すべてのテストを再実行し、成功を確認。

#### 実行コマンド / 結果
```bash
bash tests/sandbox_cli.test.sh
for t in tests/*.sh; do bash "$t"; done
```

#### 変更したファイル
- `tests/sandbox_cli.test.sh` - 期待値と grep の扱いを修正

#### コミット
- 実施せず（禁止操作のため）

#### メモ
- 該当なし

---

### 2026-01-23 12:43 - 13:12

#### 対象
- Step: S03
- AC/EC: AC-003

#### 実施内容
- tmux + エージェント起動の補助スクリプト（`scripts/tmux-*`）を削除し、関連ドキュメント/ビルド手順から参照を除去。
- テストを再実行して成功を確認。

#### 実行コマンド / 結果
```bash
rg -n "\\btmux-(claude|codex|opencode)\\b" .
rm scripts/tmux-claude scripts/tmux-codex scripts/tmux-opencode

bash tests/sandbox_cli.test.sh
for t in tests/*.sh; do bash "$t"; done
```

#### 変更したファイル
- `Dockerfile` - tmux ラッパーコマンド登録を削除
- `README.md` - tmux 起動手順の削除
- `CLAUDE.md` - tmux 起動手順の削除
- `.spec-dock/current/design.md` - 変更計画/見取り図の更新
- `.spec-dock/current/plan.md` - S03 を追加
- `.spec-dock/current/discussions/garbage-files.md` - 削除済み項目を追記

#### 変更・削除したファイル
- 削除: `scripts/tmux-claude`, `scripts/tmux-codex`, `scripts/tmux-opencode`

#### コミット
- 実施せず（禁止操作のため）

#### メモ
- 該当なし

---

### 2026-01-23 13:12 - 13:57

#### 対象
- Step: S04
- AC/EC: AC-003

#### 実施内容
- `CHANGELOG.md` / `CLAUDE.md` / `README.md` / `.devcontainer/` を削除。
- `.gitignore` から `.devcontainer` 関連の ignore を削除。
- テストを再実行して成功を確認。

#### 実行コマンド / 結果
```bash
rm CHANGELOG.md CLAUDE.md README.md
rm -rf .devcontainer
rg -n "\\bREADME\\.md\\b|\\bCLAUDE\\.md\\b|\\bCHANGELOG\\.md\\b|\\.devcontainer" .

for t in tests/*.sh; do bash "$t"; done
```

#### 変更したファイル
- `.gitignore` - `.devcontainer` の ignore を削除
- `.spec-dock/current/design.md` - 変更計画の更新
- `.spec-dock/current/plan.md` - S04 を追加
- `.spec-dock/current/discussions/garbage-files.md` - 削除済み項目を追記

#### 変更・削除したファイル
- 削除: `CHANGELOG.md`, `CLAUDE.md`, `README.md`, `.devcontainer/`

#### コミット
- 実施せず（禁止操作のため）

#### メモ
- `README.md` は後で作り直す前提で一旦削除

---

### 2026-01-23 13:57 - 14:13

#### 対象
- Step: S01
- AC/EC: AC-001, AC-002

#### 実施内容
- `.env.example` を現行運用向けの雛形として更新（`.env` 形式、必要な環境変数の整理、旧 `sandbox.config` 形式の記述を除去）。

#### 実行コマンド / 結果
```bash
# .env.example を編集
```

#### 変更したファイル
- `.env.example` - 現行運用向けテンプレートに更新

#### コミット
- 実施せず（禁止操作のため）

#### メモ
- 該当なし

---

## 遭遇した問題と解決 (任意)
- 該当なし

## 学んだこと (任意)
- 該当なし

## 今後の推奨事項 (任意)
- 必要に応じて `bash tests/sandbox_cli.test.sh` などを実行し、CLI への影響を確認する。

## 省略/例外メモ (必須)
- 該当なし
