---
種別: 実装報告書
機能ID: "SBX-CODEX-AUTO-BOOTSTRAP"
機能名: "sandbox codex: Trust状態に応じた自動Bootstrap/YOLO切替"
関連Issue: []
状態: "draft"
作成者: "Codex CLI (GPT-5.2)"
最終更新: "2026-01-26"
依存: ["requirement.md", "design.md", "plan.md"]
---

# SBX-CODEX-AUTO-BOOTSTRAP sandbox codex: Trust状態に応じた自動Bootstrap/YOLO切替 — 実装報告（LOG）

## 実装サマリー (任意)
- 計画フェーズ（要件/設計）を仕切り直しし、Trust 未確立でも skills を成立させるための “bootstrap → Trust → YOLO” 自動切替を `sandbox codex` に組み込む方針を仕様化した。
- `-c/--config` による `projects` 注入では解決しない前提のもと、Codex 標準の Trust 導線を利用する（外部ツールで `projects` を機械編集しない）設計に変更した。

## 実装記録（セッションログ） (必須)

### 2026-01-25 22:20 - 22:58

#### 対象
- Phase: Planning（requirement/design）
- AC/EC: AC-001〜AC-003, EC-001〜EC-003（requirement.md）

#### 実施内容
- 既存実装調査:
  - `host/sandbox` の `sandbox codex` / `sandbox shell` / mount-root/workdir 算出ロジックを確認
  - `docker-compose.yml` の `.agent-home/.codex` ↔ `/home/node/.codex` bind mount を確認
- 公式仕様調査（web）:
  - Codex CLI options:
    - `--cd/-C` / `--skip-git-repo-check` / `--sandbox` / `--ask-for-approval`
    - `--config/-c` は `key=value` で値は JSON 解釈（TOML断片は不可）
  - `codex resume` が global flags を受け取れることを確認
- ドキュメント作成:
  - `.spec-dock/current/requirement.md`（TBD含む）
  - `.spec-dock/current/design.md`（詳細設計・変更計画）
  - 手動受け入れ手順 / ヒアリング資料を discussions に追加

#### 実行コマンド / 結果
```bash
# 既存実装・テンプレ確認
ls
ls .spec-dock && ls .spec-dock/current
sed -n '1,200p' .spec-dock/docs/spec-dock-guide.md
sed -n '1,240p' host/sandbox
rg -n "\\bcodex\\b" host/sandbox scripts tests docs | head
sed -n '600,760p' tests/sandbox_cli.test.sh
sed -n '1,220p' docker-compose.yml

# （web調査）Codex CLI options / resume の仕様確認
# - web.run で developers.openai.com の公式ページを参照

# テンプレ置換漏れチェック
rg -n "<FEATURE_ID>|<FEATURE_NAME>|<ISSUE|<YOUR_NAME>|YYYY-MM-DD" .spec-dock/current/requirement.md .spec-dock/current/design.md || true

# 作業時刻
date '+%Y-%m-%d %H:%M'

結果:
- `sandbox codex` は現状 `codex resume` をそのまま起動しており、Trust 状態に応じた mode 切替は未実装。
- `--config/-c` は `key=value` で値を JSON として解釈するため、TOML 断片を渡しても期待どおりにならない。
- `codex resume` は global flags（`--cd/-C` 等）を受け取れる。
```

#### 変更したファイル
- `.spec-dock/current/requirement.md` - 要件定義を新方針で作成
- `.spec-dock/current/design.md` - 設計書を新方針で作成（詳細設計/変更計画/テスト戦略）
- `.spec-dock/current/discussions/questions-for-user.md` - 未確定事項のヒアリング資料
- `.spec-dock/current/discussions/manual-acceptance.md` - 手動受け入れ手順

#### コミット
- なし（禁止コマンドのため `git commit` は実施しない）

#### メモ
- 次回: 質問（Q-001〜Q-003）に回答が揃い次第、requirement/design を確定し、plan.md を作成する

---

### 2026-01-26 00:00 - 00:23

#### 対象
- Phase: Planning（requirement/design/plan）
- AC/EC: AC-001〜AC-003, EC-001〜EC-003

#### 実施内容
- ヒアリング回答（`1A 2A 3B`）を反映し、未確定事項（Q-001〜Q-003）を解消。
- `plan.md` を新規作成し、TDD（Red→Green→Refactor）で進める実装ステップを定義。

#### 実行コマンド / 結果
```bash
# ドキュメント確認
sed -n '1,260p' .spec-dock/current/requirement.md
sed -n '1,260p' .spec-dock/current/design.md
sed -n '1,240p' .spec-dock/current/plan.md

# テンプレ置換漏れチェック
rg -n "<FEATURE_ID>|<FEATURE_NAME>|<ISSUE_NUMBER_OR_URL>|<YOUR_NAME>|draft \\| approved|YYYY-MM-DD" .spec-dock/current || true

結果:
- Q-001〜Q-003 は回答済みとして requirement/design に反映済み。
- plan.md を作成し、実装フェーズへ進む準備が整った（状態は draft のまま）。
```

#### 変更したファイル
- `.spec-dock/current/requirement.md` - `1A 2A 3B` の決定を反映（TBD解消）
- `.spec-dock/current/design.md` - 決定に合わせて設計を更新（競合引数/非Git/YOLOフラグ）
- `.spec-dock/current/plan.md` - 実装計画（TDD）を新規作成

#### コミット
- なし（禁止コマンドのため `git commit` は実施しない）

#### メモ
- 次回: requirement/design/plan のレビュー→承認後、S01 から実装着手

---

### 2026-01-26 00:23 - 00:41

#### 対象
- Phase: Planning（review反映）
- Docs: requirement/design/plan

#### 実施内容
- レビュア指摘の矛盾修正:
  - EC-002（`.git` があるが rev-parse 失敗）を “bootstrap + 警告（skip-gitは付けない）” に固定。
  - 設計の詳細分岐を `find_git_marker` + `git_state` 前提に修正（non_git / git_ok / git_error）。
- 実装計画の補強:
  - help 更新ステップ（S08）を追加し、手動受け入れを S09 へ移動。
  - S07 で短縮形（`-c/-C/-a/-s/-p`）を最低1つカバーする旨を追記。
  - S01 を「誤った既存テストの是正」である旨を明記。

#### 実行コマンド / 結果
```bash
sed -n '1,240p' .spec-dock/current/requirement.md
sed -n '1,240p' .spec-dock/current/design.md
sed -n '1,260p' .spec-dock/current/plan.md

結果:
- requirement/design/plan の矛盾（EC-002 分岐）を解消し、レビュー指摘を反映した。
```

#### 変更したファイル
- `.spec-dock/current/requirement.md` - EC-002 の期待を明確化（bootstrap + warning + no-skip）
- `.spec-dock/current/design.md` - `find_git_marker` + `git_state` 分岐に修正
- `.spec-dock/current/plan.md` - help 更新ステップ追加、S01/S05/S06/S07 を補強

#### コミット
- なし（禁止コマンドのため `git commit` は実施しない）

---

### 2026-01-26 00:41 - 00:49

#### 対象
- Phase: Planning（review反映）
- Docs: requirement

#### 実施内容
- AC-003（非Git）の Given が EC-002（`.git` 有り + rev-parse 失敗）と重なる矛盾を解消:
  - AC-003 Given を「`.git` が存在しない（非Git）」に限定し、rev-parse 失敗ケースは EC-002 に委譲。

#### 変更したファイル
- `.spec-dock/current/requirement.md` - AC-003 Given を非Gitに限定

#### コミット
- なし（禁止コマンドのため `git commit` は実施しない）

---

### 2026-01-26 00:49 - 00:54

#### 対象
- Step: S01
- AC/EC: MUST NOT（config機械編集禁止の回帰防止）

#### 実施内容
- `sandbox shell` が Codex config を生成しないことを回帰防止として固定するため、誤っていたテストを置換。

#### 実行コマンド / 結果
```bash
bash tests/sandbox_cli.test.sh

結果: 全テスト成功
```

#### 変更したファイル
- `tests/sandbox_cli.test.sh` - `shell_trusts_git_repo_root_for_codex` を `shell_does_not_write_codex_config` に置換

#### コミット
- なし（禁止コマンドのため `git commit` は実施しない）

---

### 2026-01-26 00:54 - 00:55

#### 対象
- Step: S02
- AC/EC: AC-001/AC-002/AC-003（共通要件）

#### 実施内容
- `sandbox codex` の `codex resume` に常に `--cd <container_workdir>` を付与する実装とテストを追加。

#### 実行コマンド / 結果
```bash
bash tests/sandbox_cli.test.sh

結果: 全テスト成功
```

#### 変更したファイル
- `host/sandbox` - `codex resume` 起動時に `--cd` を常時付与
- `tests/sandbox_cli.test.sh` - `codex_inner_adds_cd_to_resume` を追加

#### コミット
- なし（禁止コマンドのため `git commit` は実施しない）

---

### 2026-01-26 00:55 - 00:59

#### 対象
- Step: S03
- AC/EC: AC-001

#### 実施内容
- Trust 済み Git の場合に YOLO で起動する判定ロジックを追加。
- Trust 判定（config.toml 読み取り）と git_state 分岐を導入。

#### 実行コマンド / 結果
```bash
bash tests/sandbox_cli.test.sh

結果: 全テスト成功
```

#### 変更したファイル
- `host/sandbox` - `compute_codex_mode`/`is_codex_project_trusted` を追加し YOLO 引数を注入
- `tests/sandbox_cli.test.sh` - `codex_inner_runs_yolo_when_trusted` を追加

#### コミット
- なし（禁止コマンドのため `git commit` は実施しない）

---

### 2026-01-26 00:59 - 01:03

#### 対象
- Step: S04
- AC/EC: AC-002, EC-001, EC-003

#### 実施内容
- 未Trust Git の bootstrap 起動＋案内をテストで固定。
- Trust 判定の awk ロジックを修正（END での無条件 exit を排除）。
- テスト側に `.git` 生成を追加し、git/non-git の区別を正しく観測。

#### 実行コマンド / 結果
```bash
bash tests/sandbox_cli.test.sh

結果: 全テスト成功
```

#### 変更したファイル
- `host/sandbox` - trust 判定の awk バグ修正
- `tests/sandbox_cli.test.sh` - bootstrap テスト追加・`.git` セットアップ追加

#### コミット
- なし（禁止コマンドのため `git commit` は実施しない）

---

### 2026-01-26 01:03 - 01:04

#### 対象
- Step: S05
- AC/EC: AC-003

#### 実施内容
- 非Git時に YOLO + `--skip-git-repo-check` が付与されることをテストで固定。

#### 実行コマンド / 結果
```bash
bash tests/sandbox_cli.test.sh

結果: 全テスト成功
```

#### 変更したファイル
- `tests/sandbox_cli.test.sh` - `codex_inner_non_git_runs_yolo_with_skip_git_repo_check` を追加

#### コミット
- なし（禁止コマンドのため `git commit` は実施しない）

---

### 2026-01-26 01:04 - 01:05

#### 対象
- Step: S06
- AC/EC: EC-002

#### 実施内容
- `.git` はあるが `rev-parse` 失敗時に bootstrap + 警告で起動する挙動をテストで固定。

#### 実行コマンド / 結果
```bash
bash tests/sandbox_cli.test.sh

結果: 全テスト成功
```

#### 変更したファイル
- `tests/sandbox_cli.test.sh` - `codex_inner_git_rev_parse_failure_warns_and_runs_bootstrap` を追加

#### コミット
- なし（禁止コマンドのため `git commit` は実施しない）

---

### 2026-01-26 01:05 - 01:07

#### 対象
- Step: S07
- AC/EC: MUST（競合引数の拒否）

#### 実施内容
- `sandbox codex` に競合引数検知を追加し、`--yolo/-c/-C/-a/-s/-p` 等が渡されたらエラーにする。
- compose を呼ばないことをテストで固定。

#### 実行コマンド / 結果
```bash
bash tests/sandbox_cli.test.sh

結果: 全テスト成功
```

#### 変更したファイル
- `host/sandbox` - 競合引数の検知ロジックを追加
- `tests/sandbox_cli.test.sh` - `codex_rejects_conflicting_args_before_compose` を追加

#### コミット
- なし（禁止コマンドのため `git commit` は実施しない）

---

### 2026-01-26 01:22 - 01:24

#### 対象
- Step: S08
- AC/EC: なし（ヘルプ文言更新）

#### 実施内容
- `sandbox codex --help` に自動 bootstrap/YOLO 切替と競合引数拒否の注意を追記。
- ヘルプ文言の更新をテストで固定。

#### 実行コマンド / 結果
```bash
bash tests/sandbox_cli.test.sh

結果: 全テスト成功
```

#### 変更したファイル
- `host/sandbox` - `print_help_codex` の文言更新
- `tests/sandbox_cli.test.sh` - `help_codex_mentions_auto_bootstrap_and_conflicts` を追加

#### コミット
- なし（禁止コマンドのため `git commit` は実施しない）

---

### YYYY-MM-DD HH:MM - HH:MM

#### 対象
- Step: ...
- AC/EC: ...

#### 実施内容
- ...

---

### 2026-01-26 01:28 - 01:30

#### 対象
- Step: S09
- AC/EC: 手動受け入れ（bootstrap → trust → yolo）

#### 実施内容
- この環境では対象プロジェクトの実体（/srv/mount/...）が無いため、手動受け入れの再現を実行できませんでした。
- 手順は `.spec-dock/current/discussions/manual-acceptance.md` に整理済みのため、実環境での実行を依頼します。

#### 実行コマンド / 結果
- 実行なし（実環境不足）

#### 変更したファイル
- なし

#### コミット
- なし（禁止コマンドのため `git commit` は実施しない）

---

### 2026-01-26 02:10 - 02:20

#### 対象
- Step: S05（非Gitの挙動調整）
- AC/EC: AC-003 / EC-001

#### 実施内容
- 非Git時に `--skip-git-repo-check` を付与しないよう変更（現行CLIで未対応のため）。
- `sandbox codex --help` の文言を修正。
- テストと仕様ドキュメントを整合更新。

#### 実行コマンド / 結果
```bash
bash tests/sandbox_cli.test.sh

結果: 全テスト成功
```

#### 変更したファイル
- `host/sandbox` - `--skip-git-repo-check` 付与を削除、ヘルプ文言更新
- `tests/sandbox_cli.test.sh` - 非Gitテストを「skip無し」に更新
- `.spec-dock/current/requirement.md` - 非Gitの受け入れ条件/要件を更新
- `.spec-dock/current/design.md` - 非Gitの引数方針を更新
- `.spec-dock/current/plan.md` - S05の期待/テスト名を更新
- `.spec-dock/current/discussions/manual-acceptance.md` - 非Gitの観測点を更新

#### コミット
- なし（禁止コマンドのため `git commit` は実施しない）

---

### 2026-01-26 02:40 - 02:50

#### 対象
- Review対応: mount-root が repo 内サブディレクトリのケース
- AC/EC: EC-004

#### 実施内容
- repo root が mount-root 外の場合は non-git 扱いで YOLO 起動するよう修正。
- stderr に警告を出す仕様を追加。
- テストを追加して回帰防止。
- 要件/設計/計画に EC-004 を追記。

#### 実行コマンド / 結果
```bash
bash tests/sandbox_cli.test.sh

結果: 全テスト成功
```

#### 変更したファイル
- `host/sandbox` - mount-root 外の repo root を non-git 扱いに変更
- `tests/sandbox_cli.test.sh` - `codex_inner_repo_root_outside_mount_root_is_treated_as_non_git` を追加
- `.spec-dock/current/requirement.md` - EC-004 追加
- `.spec-dock/current/design.md` - trust_key 判定の分岐を追記
- `.spec-dock/current/plan.md` - EC-004/S05 の観測点を追記

#### コミット
- なし（禁止コマンドのため `git commit` は実施しない）

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
