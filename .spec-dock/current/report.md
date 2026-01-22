---
種別: 実装報告書
機能ID: "FEAT-005"
機能名: "動的マウント起動（任意ディレクトリをSandboxとして起動）"
関連Issue: ["https://github.com/chemitaro/agent-sandbox/issues/5"]
状態: "draft"
作成者: "Codex CLI"
最終更新: "2026-01-22"
依存: ["requirement.md", "design.md", "plan.md"]
---

# FEAT-005 動的マウント起動（任意ディレクトリをSandboxとして起動） — 実装報告（LOG）

## 実装サマリー (任意)
- （未記載 / 設計フェーズ）

## 実装記録（セッションログ） (必須)

> 時刻表記: JST (UTC+9)

### 2026-01-22 - 2026-01-22 15:26

#### 対象
- Step: （未着手 / 設計更新）
- AC/EC: AC-020

#### 実施内容
- `sandbox status` コマンドの仕様追加（要件/設計の更新）。
- 出力内容（container_name/status/container_id/mount_root/workdir）と exit code 方針（存在しない場合も exit 0）を固定。

#### 実行コマンド / 結果
```bash
# ドキュメントの参照（抜粋）
sed -n '1,260p' .spec-dock/current/requirement.md
sed -n '1,260p' .spec-dock/current/design.md
rg -n "sandbox status|AC-020" .spec-dock/current/requirement.md .spec-dock/current/design.md
```

#### 変更したファイル
- `.spec-dock/current/requirement.md` - `sandbox status`（AC-020）を追加
- `.spec-dock/current/design.md` - IF-CLI-001/具体設計/マッピング/テスト戦略に `sandbox status` を反映

#### コミット
- （未実施 / 禁止）

#### メモ
- 実装/テストはまだ着手しない（設計フェーズ）。

---

### 2026-01-22 15:26 - 2026-01-22 15:46

#### 対象
- Step: （未着手 / 設計更新）
- AC/EC: AC-018, AC-019, AC-020

#### 実施内容
- レビューフィードバックを反映し、以下を仕様として明確化:
  - `help/name/status` は副作用なし（`.env` / `.agent-home` の作成を含むホスト側ファイル生成/更新をしない）
  - `workdir=PWD` の `PWD` は “呼び出し元PWD”（`CALLER_PWD`）である
  - ヘルプはパス検証より先に処理し、無効なパス指定が混ざっていても exit 0 で表示できる
  - `TZ=` が空文字の場合は未設定扱いとして検出注入する（空のままにしない）
  - コンテナ存在確認を `docker ps -a` の出力パースではなく `docker inspect` ベースに寄せる

#### 実行コマンド / 結果
```bash
rg -n "CALLER_PWD|help --workdir|docker inspect|TZ=\\)" .spec-dock/current/design.md .spec-dock/current/requirement.md
```

#### 変更したファイル
- `.spec-dock/current/requirement.md` - help/name/status の副作用なし・ヘルプの早期処理・呼び出し元PWDの明記
- `.spec-dock/current/design.md` - CALLER_PWD 固定、compose事前準備の適用範囲、TZ空文字ルール、存在確認の inspect 化、テスト観点を追記

#### コミット
- （未実施 / 禁止）

#### メモ
- まだ設計フェーズ。次はユーザー承認後に `plan.md` を作成して実装へ進む。

---

### 2026-01-22 15:46 - 2026-01-22 16:14

#### 対象
- Step: （計画フェーズ / ドキュメント更新）
- AC/EC: AC-015, AC-016, AC-018, AC-020, EC-005

#### 実施内容
- レビューフィードバックを反映し、以下を仕様として明確化:
  - 用語統一: `PWD` 表記を “呼び出し元PWD（= sandbox 実行時のPWD）” に統一
  - `-h/--help` は **引数のどこに現れても最優先**（`sandbox shell --workdir /nope --help` でも exit 0）
  - `stop/down` は “対象なし” が確定した場合は **真に no-op**（`docker compose` を呼ばず、`.env/.agent-home` も作らない）
  - Docker/Compose 不在・デーモン疎通不可は `not-found` と区別して **非0でエラー**（EC-005）
  - `name/status` の stdout 契約を守るため、デバッグログは stderr に寄せる方針を追加
- `.spec-dock/current/plan.md` を FEAT-005 の実装計画として作成（ステップ分割/要件マッピング）。

#### 実行コマンド / 結果
```bash
rg -n "\\bPWD\\b|-h/--help|no-op|EC-005|stderr" .spec-dock/current/requirement.md .spec-dock/current/design.md
sed -n '1,120p' .spec-dock/current/plan.md
```

#### 変更したファイル
- `.spec-dock/current/requirement.md` - PWD表記統一、help優先順位、stop/down no-op、EC-005、stdout/stderr方針
- `.spec-dock/current/design.md` - help優先順位（どこでも）、0.1適用範囲、stop/down no-op、docker疎通/失敗分類、stdout/stderr方針
- `.spec-dock/current/plan.md` - 実装計画を記述（S01-S12）

#### コミット
- （未実施 / 禁止）

#### メモ
- 次は plan.md に従って実装フェーズへ進む（ユーザー承認後）。

### 2026-01-22 17:20 - 2026-01-22 17:40

#### 対象
- Step: S01
- AC/EC: AC-018

#### 実施内容
- `sandbox` の help 表示を最優先で処理するテストを追加。
- ホスト側 CLI エントリ `host/sandbox` を新規作成し、`help/-h/--help` の表示を実装。
- help 実行時に docker/git や `.env`/`.agent-home` が触られないことをテストで担保。

#### 実行コマンド / 結果
```bash
mkdir -p tests
cat > tests/_helpers.sh <<'EOF'
# helpers for bash tests
EOF
cat > tests/sandbox_cli.test.sh <<'EOF'
# help tests
EOF
chmod +x tests/_helpers.sh tests/sandbox_cli.test.sh
cat > host/sandbox <<'EOF'
# host CLI entrypoint
EOF
chmod +x host/sandbox
bash tests/sandbox_cli.test.sh
```

#### 変更したファイル
- `tests/_helpers.sh` - テスト共通ヘルパ（stub/アサート/実行）を追加
- `tests/sandbox_cli.test.sh` - S01（help最優先）のテストを追加
- `host/sandbox` - CLI エントリを追加（help 先行処理）

#### コミット
- （未実施 / 禁止）

#### メモ
- S01 のテストが通過。次は S02 に着手。

---

### 2026-01-22 17:40 - 2026-01-22 18:10

#### 対象
- Step: S02
- AC/EC: AC-019, AC-004, EC-004

#### 実施内容
- `sandbox name` のテスト（1行stdout/slug/hash/長さ/sha256sum→shasum fallback）を追加。
- `host/sandbox` にコンテナ名合成ロジックを実装（slug正規化・hash12）。
- テストヘルパの `run_cmd` を修正し、空白パスを正しく扱えるように修正。

#### 実行コマンド / 結果
```bash
cat > tests/sandbox_name.test.sh <<'EOF'
# sandbox name tests
EOF
chmod +x tests/sandbox_name.test.sh
bash tests/sandbox_cli.test.sh
bash tests/sandbox_name.test.sh
```

#### 変更したファイル
- `tests/_helpers.sh` - `run_cmd` の引数クオート修正
- `tests/sandbox_cli.test.sh` - `sandbox name` の stdout 1行テストを追加
- `tests/sandbox_name.test.sh` - コンテナ名合成のユニットテストを追加
- `host/sandbox` - `sandbox name` を実装（slug/hash12/パス解決）

#### コミット
- （未実施 / 禁止）

#### メモ
- S02 のテストが通過。次は S03 に着手。

---

### 2026-01-22 18:10 - 2026-01-22 18:45

#### 対象
- Step: S03
- AC/EC: AC-002, AC-007, AC-012, EC-001, EC-002

#### 実施内容
- パス決定/包含/コンテナ内変換のテストを追加（`tests/sandbox_paths.test.sh`）。
- `host/sandbox` を source して関数テストできるように `main()` ガードを導入。
- `determine_paths` / `compute_container_workdir` / `is_subpath` を実装し、境界判定を明確化。

#### 実行コマンド / 結果
```bash
cat > tests/sandbox_paths.test.sh <<'EOF'
# path resolution tests
EOF
chmod +x tests/sandbox_paths.test.sh
bash tests/sandbox_paths.test.sh
bash tests/sandbox_cli.test.sh
bash tests/sandbox_name.test.sh
```

#### 変更したファイル
- `tests/sandbox_paths.test.sh` - パス決定/包含/変換のユニットテストを追加
- `host/sandbox` - source 対応とパス決定ロジックを追加

#### コミット
- （未実施 / 禁止）

#### メモ
- S03 のテストが通過。次は S04 に着手。

---

### 2026-01-22 18:45 - 2026-01-22 19:20

#### 対象
- Step: S04
- AC/EC: AC-001, AC-005, AC-013, EC-003

#### 実施内容
- git worktree の自動推定と “広すぎる” ガードのテストを追加（`tests/sandbox_git_detect.test.sh`）。
- `host/sandbox` に git worktree 解析（LCA）とガード（禁止パス + MAX_UP_LEVEL）を実装。
- `rev-parse` 失敗時のエラー（EC-003）と非gitフォールバックを明確化。

#### 実行コマンド / 結果
```bash
cat > tests/sandbox_git_detect.test.sh <<'EOF'
# git auto-detect tests
EOF
chmod +x tests/sandbox_git_detect.test.sh
bash tests/sandbox_git_detect.test.sh
bash tests/sandbox_cli.test.sh
bash tests/sandbox_name.test.sh
bash tests/sandbox_paths.test.sh
```

#### 変更したファイル
- `tests/sandbox_git_detect.test.sh` - worktree/LCA/ガードのテストを追加
- `host/sandbox` - git 検出/ワークツリー解析/ガード/非gitフォールバックを追加

#### コミット
- （未実施 / 禁止）

#### メモ
- S04 のテストが通過。次は S05 に着手。

---

### 2026-01-22 19:20 - 2026-01-22 19:50

#### 対象
- Step: S05
- AC/EC: EC-005

#### 実施内容
- Docker/Compose 不在・デーモン疎通不可のエラーをテストで担保。
- `host/sandbox` に Docker 依存コマンド用の事前チェックを追加（`docker info`）。
- help/name が Docker 不在でも動作することをテストで確認。

#### 実行コマンド / 結果
```bash
bash tests/sandbox_cli.test.sh
bash tests/sandbox_name.test.sh
bash tests/sandbox_paths.test.sh
bash tests/sandbox_git_detect.test.sh
```

#### 変更したファイル
- `tests/sandbox_cli.test.sh` - Docker 不在/疎通不可のテストを追加
- `host/sandbox` - Docker 事前チェックを追加

#### コミット
- （未実施 / 禁止）

#### メモ
- S05 のテストが通過。次は S06 に着手。

---

### 2026-01-22 19:50 - 2026-01-22 20:40

#### 対象
- Step: S06
- AC/EC: AC-014, AC-011, AC-003

#### 実施内容
- `sandbox up` のテスト（compose 実行・env注入・.env/.agent-home作成・compose選択・TZ注入）を追加。
- `host/sandbox` に `up` 実装（compose 選択、環境注入、TZ ルール、.env/.agent-home 作成）。

#### 実行コマンド / 結果
```bash
bash tests/sandbox_cli.test.sh
bash tests/sandbox_name.test.sh
bash tests/sandbox_paths.test.sh
bash tests/sandbox_git_detect.test.sh
```

#### 変更したファイル
- `tests/sandbox_cli.test.sh` - `sandbox up` のテストを追加（compose/env/.env/.agent-home/TZ/compose検出）
- `tests/_helpers.sh` - PATH 変更時の hash リセットを追加
- `host/sandbox` - `up` 実装（compose 起動・env注入・TZ処理）

#### コミット
- （未実施 / 禁止）

#### メモ
- S06 のテストが通過。次は S07 に着手。

## 遭遇した問題と解決 (任意)
- 該当なし

## 学んだこと (任意)
- 該当なし

## 今後の推奨事項 (任意)
- 該当なし

## 省略/例外メモ (必須)
- 該当なし

---

### 2026-01-22 20:40 - 2026-01-22 21:05

#### 対象
- Step: S07
- AC/EC: AC-001, AC-002, AC-007, AC-012, AC-013

#### 実施内容
- `sandbox shell` のテスト（exec -w と DoD env 注入）を追加。
- `host/sandbox` に shell 実装（up 後に exec、env 注入の共通化）。

#### 実行コマンド / 結果
```bash
bash tests/sandbox_cli.test.sh
```

#### 変更したファイル
- `tests/sandbox_cli.test.sh` - shell の exec/DoD env テストを追加
- `host/sandbox` - compose 実行の共通化と `shell` 実装

#### コミット
- （未実施 / 禁止）

#### メモ
- S07 のテストが通過。次は S08 に着手。

---

### 2026-01-22 21:05 - 2026-01-22 21:30

#### 対象
- Step: S08
- AC/EC: AC-017

#### 実施内容
- `sandbox build` のテスト（buildのみ・.env/.agent-home 作成）を追加。
- `host/sandbox` に build 実装を追加。

#### 実行コマンド / 結果
```bash
bash tests/sandbox_cli.test.sh
```

#### 変更したファイル
- `tests/sandbox_cli.test.sh` - build_only のテストを追加
- `host/sandbox` - `build` 実装を追加

#### コミット
- （未実施 / 禁止）

#### メモ
- S08 のテストが通過。次は S09 に着手。

---

### 2026-01-22 21:30 - 2026-01-22 22:05

#### 対象
- Step: S09
- AC/EC: AC-015, AC-016

#### 実施内容
- `sandbox stop/down` のテスト（no-op と compose 実行）を追加。
- `host/sandbox` に stop/down 実装（inspect 判定、no-op、compose 実行）。

#### 実行コマンド / 結果
```bash
bash tests/sandbox_cli.test.sh
```

#### 変更したファイル
- `tests/sandbox_cli.test.sh` - stop/down のテストを追加
- `host/sandbox` - stop/down 実装を追加

#### コミット
- （未実施 / 禁止）

#### メモ
- S09 のテストが通過。次は S10 に着手。

---

### 2026-01-22 22:05 - 2026-01-22 22:45

#### 対象
- Step: S10
- AC/EC: AC-020

#### 実施内容
- `sandbox status` のテスト（key/value出力、not-found、Dockerエラー、無副作用）を追加。
- `host/sandbox` に status 実装（inspect 取得、key/value 出力）。

#### 実行コマンド / 結果
```bash
bash tests/sandbox_cli.test.sh
```

#### 変更したファイル
- `tests/sandbox_cli.test.sh` - status のテストを追加
- `host/sandbox` - status 実装を追加

#### コミット
- （未実施 / 禁止）

#### メモ
- S10 のテストが通過。次は S11 に着手。

---

### 2026-01-22 22:45 - 2026-01-22 23:00

#### 対象
- Step: S11
- AC/EC: AC-008

#### 実施内容
- `scripts/install-sandbox.sh` を追加（/usr/local/bin/sandbox への symlink 作成）。

#### 実行コマンド / 結果
```bash
# 手動検証は未実施（権限が絡むため）。
```

#### 変更したファイル
- `scripts/install-sandbox.sh` - symlink インストーラを追加

#### コミット
- （未実施 / 禁止）

#### メモ
- S11 の実装を追加。次は S12 に着手。

---

### 2026-01-22 23:00 - 2026-01-22 23:45

#### 対象
- Step: S12

#### 実施内容
- README/CLAUDE/Makefile を新しい `sandbox` CLI 前提に更新。
- 旧フロー依存スクリプトを整理（`scripts/generate-env.sh` / `scripts/migrate-config.sh` を削除）。
- Slack 通知の案内を `.env` 前提に更新。

#### 実行コマンド / 結果
```bash
# ドキュメント更新のみ
```

#### 変更したファイル
- `README.md` - 新しい CLI フローに更新
- `CLAUDE.md` - 動的マウント前提のガイドに刷新
- `Makefile` - 旧フロー削除、tmux/installer中心に整理
- `scripts/slack-notify.js` - .env 前提の文言へ更新
- `scripts/install-sandbox.sh` - 既存（S11で追加）
- `scripts/generate-env.sh` - 削除
- `scripts/migrate-config.sh` - 削除

#### コミット
- （未実施 / 禁止）

#### メモ
- S12 の更新完了。次は S13（DoD 実動）を確認。

---

### 2026-01-22 23:45 - 2026-01-22 23:55

#### 対象
- Step: S13（手動 DoD 実動）

#### 実施内容
- 実行環境で Docker の疎通を確認。
- 手動検証は Docker が利用可能な環境で実施する必要があるため保留。

#### 実行コマンド / 結果
```bash
docker info >/dev/null 2>&1; echo $?
# => 1 (Docker デーモンに疎通できない)
```

#### 変更したファイル
- なし

#### コミット
- （未実施 / 禁止）

#### メモ
- Docker が利用できる環境で `sandbox shell` + DoD 検証スクリプトを実行してください。
- 参考対象: /Users/iwasawayuuta/workspace/product/taikyohiyou_project

---

### 2026-01-23 00:00 - 2026-01-23 00:40

#### 対象
- Review fixes: symlink root, subcommand parsing, path existence, TZ detection, Dockerfile comments

#### 実施内容
- SANDBOX_ROOT を symlink 解決済みスクリプトパスから算出。
- サブコマンド判定で `--mount-root/--workdir` の値を誤認しないように修正。
- `mount-root/workdir` の存在チェックを追加。
- macOS 向けに TZ 自動検出を安全側へ修正。
- Dockerfile コメントを新 CLI に合わせて更新。
- テスト追加: default shell の誤認防止、存在しないパスのエラー。

#### 実行コマンド / 結果
```bash
bash tests/sandbox_cli.test.sh
bash tests/sandbox_paths.test.sh
```

#### 変更したファイル
- `host/sandbox` - symlink 安全化、サブコマンド判定、パス存在チェック、TZ検出修正
- `tests/sandbox_cli.test.sh` - サブコマンド誤認防止テストを追加
- `tests/sandbox_paths.test.sh` - 存在しないパスのテストを追加
- `Dockerfile` - コメント更新

#### コミット
- （未実施 / 禁止）

---

### 2026-01-23 01:00 - 2026-01-23 01:30

#### 対象
- Review fixes: Compose project 名の安全化

#### 実施内容
- `COMPOSE_PROJECT_NAME` をコンテナ名とは別に安全な値へ正規化。
- 低文字化 + 許可文字 `[a-z0-9_-]` のみ許可し、hash12 を維持。
- テスト追加: 大文字/ドットを含むパスで compose project 名が安全になることを確認。

#### 実行コマンド / 結果
```bash
bash tests/sandbox_cli.test.sh
bash tests/sandbox_paths.test.sh
```

#### 変更したファイル
- `host/sandbox` - compose project 名生成/注入を分離
- `tests/sandbox_cli.test.sh` - compose project 名のテストを追加

#### コミット
- （未実施 / 禁止）

---

### 2026-01-23 01:30 - 2026-01-23 02:00

#### 対象
- Review fix: Compose project 名の安全化（続き）

#### 実施内容
- `COMPOSE_PROJECT_NAME` を安全名へ分離し、`docker-compose.yml` の `name:` も安全名に合わせた。
- テストに安全名の検証を追加。
- 設計/計画の記述を更新（`COMPOSE_PROJECT_NAME` は安全名）。

#### 実行コマンド / 結果
```bash
bash tests/sandbox_cli.test.sh
bash tests/sandbox_paths.test.sh
```

#### 変更したファイル
- `host/sandbox` - compose project 名生成/注入の分離
- `tests/sandbox_cli.test.sh` - compose project 名のテストを追加
- `docker-compose.yml` - name を COMPOSE_PROJECT_NAME に変更
- `.spec-dock/current/design.md` - 設計の記述更新
- `.spec-dock/current/plan.md` - テスト観測点の記述更新

#### コミット
- （未実施 / 禁止）

---

### 2026-01-23 02:00 - 2026-01-23 02:30

#### 対象
- Step: S14（prunable worktree の無視）

#### 実施内容
- `git worktree list --porcelain` に存在しないパスが含まれる場合はスキップするように修正。
- worktree 候補が空になった場合は `repo_root` を候補に加える。
- テスト追加: prunable worktree を含むケース。

#### 実行コマンド / 結果
```bash
bash tests/sandbox_git_detect.test.sh
```

#### 変更したファイル
- `host/sandbox` - prunable worktree を除外
- `tests/sandbox_git_detect.test.sh` - prunable worktree のテストを追加

#### コミット
- （未実施 / 禁止）

---

### 2026-01-23 02:30 - 2026-01-23 02:35

#### 対象
- 補足

#### 実施内容
- S13 手動検証手順を `.spec-dock/current/decision/S13_manual_steps.md` に配置。

#### 変更したファイル
- `.spec-dock/current/decision/S13_manual_steps.md`

---

### 2026-01-23 02:35 - 2026-01-23 03:00

#### 対象
- Step: S15（timezone 検出失敗の許容）

#### 実施内容
- timezone 検出の外部コマンド失敗を許容し、フォールバックできるように修正。
- テスト追加: 失敗時でも `Asia/Tokyo` にフォールバックすることを確認。

#### 実行コマンド / 結果
```bash
bash tests/sandbox_timezone.test.sh
```

#### 変更したファイル
- `host/sandbox` - detect_timezone の失敗を許容
- `tests/sandbox_timezone.test.sh` - タイムゾーン検出の失敗テストを追加
- `.spec-dock/current/requirement.md` - 非交渉制約に best-effort を追記
- `.spec-dock/current/design.md` - 検出失敗を許容する設計を追記
- `.spec-dock/current/plan.md` - S15 を追加

#### コミット
- （未実施 / 禁止）

---

### 2026-01-23 03:00 - 2026-01-23 03:30

#### 対象
- Step: S16（Python 依存撤去 / shell-only realpath）

#### 実施内容
- `realpath_safe` の Python 依存を撤去し、`readlink` + `cd -P` で正規化。
- テスト追加: `realpath` が失敗する環境でも symlink を解決できることを確認。

#### 実行コマンド / 結果
```bash
bash tests/sandbox_realpath.test.sh
```

#### 変更したファイル
- `host/sandbox` - shell-only realpath に変更
- `tests/sandbox_realpath.test.sh` - realpath フォールバックのテスト追加
- `.spec-dock/current/requirement.md` - 非交渉制約に Python 非依存を追記
- `.spec-dock/current/design.md` - パス正規化の設計を追記
- `.spec-dock/current/plan.md` - S16 追加

#### コミット
- （未実施 / 禁止）
