---
種別: 実装報告書
機能ID: "SBX-MOUNT-PROJECT-DIR"
機能名: "コンテナ内マウント先を /srv/mount/<project> 配下にしてプロジェクト名を保持"
関連Issue: []
状態: "draft"
作成者: "Codex CLI (GPT-5)"
最終更新: "2026-01-27"
依存: ["requirement.md", "design.md", "plan.md"]
---

# SBX-MOUNT-PROJECT-DIR コンテナ内マウント先を /srv/mount/<project> 配下にしてプロジェクト名を保持 — 実装報告（LOG）

## 実装サマリー (任意)
- [実装した内容の概要を2-3文で記載]

## 実装記録（セッションログ） (必須)

### 2026-01-27 14:05 - 14:11

#### 対象
- Step: S01
- AC/EC: AC-001, AC-002, EC-002

#### 実施内容
- `compute_container_workdir()` の返り値を `/srv/mount/<project_dir>/...` に変更する前提でテスト期待値を更新。
- `host/sandbox` に `compute_project_dir` / `compute_container_mount_root` を追加し、`compute_container_workdir` を新基準へ更新。

#### 実行コマンド / 結果
```bash
bash tests/sandbox_paths.test.sh

exit 0
```

#### 変更したファイル
- `host/sandbox` - `compute_container_workdir` を `/srv/mount/<project_dir>` 基準に変更
- `tests/sandbox_paths.test.sh` - 期待値を `/srv/mount/<project_dir>/...` へ更新

#### コミット
- 該当なし（コミットはユーザーが実施）

#### メモ
- なし

---

### 2026-01-27 14:11 - 14:14

#### 対象
- Step: S02, S03
- AC/EC: AC-001, AC-002, AC-003

#### 実施内容
- `PRODUCT_WORK_DIR` を `/srv/mount/<project_dir>` に変更し、`sandbox up` / `sandbox shell` の期待値を更新。
- `sandbox codex` 系の期待値（`--cd` と trust key）を新しい `/srv/mount/<project_dir>/...` へ更新。

#### 実行コマンド / 結果
```bash
bash tests/sandbox_cli.test.sh

exit 0
```

#### 変更したファイル
- `host/sandbox` - `prepare_compose_env()` で `PRODUCT_WORK_DIR` を `/srv/mount/<project_dir>` に変更
- `tests/sandbox_cli.test.sh` - up/shell/codex の期待値を更新

#### コミット
- 該当なし（コミットはユーザーが実施）

#### メモ
- `tests/sandbox_cli.test.sh` が単一ファイルで全テスト実行のため、S02/S03 の更新後にまとめて実行。

---

### 2026-01-27 14:14 - 14:16

#### 対象
- Step: S04
- AC/EC: EC-001

#### 実施内容
- `<project_dir>` の unsafe 判定を追加し、`:` と制御文字を自動変換。
- 変換が発生した場合の stderr 警告を追加。
- unsafe 変換のテストを追加。

#### 実行コマンド / 結果
```bash
bash tests/sandbox_cli.test.sh

exit 0
```

#### 変更したファイル
- `host/sandbox` - `compute_project_dir` に unsafe 変換 + stderr 警告を追加
- `tests/sandbox_cli.test.sh` - unsafe 変換のテストを追加

#### コミット
- 該当なし（コミットはユーザーが実施）

#### メモ
- なし

---

### YYYY-MM-DD HH:MM - HH:MM

#### 対象
- Step: ...
- AC/EC: ...

#### 実施内容
- ...

---

## 遭遇した問題と解決 (任意)
- 問題: ...
  - 解決: ...

## 学んだこと (任意)
- ...
- ...

## 今後の推奨事項 (任意)
- ...
- ...

## 省略/例外メモ (必須)
- 該当なし
