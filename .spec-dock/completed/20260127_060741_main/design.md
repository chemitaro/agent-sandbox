---
種別: 設計書
機能ID: "SBX-MOUNT-PROJECT-DIR"
機能名: "コンテナ内マウント先を /srv/mount/<project> 配下にしてプロジェクト名を保持"
関連Issue: []
状態: "approved"
作成者: "Codex CLI (GPT-5)"
最終更新: "2026-01-27"
依存: ["requirement.md"]
---

# SBX-MOUNT-PROJECT-DIR コンテナ内マウント先を /srv/mount/<project> 配下にしてプロジェクト名を保持 — 設計（HOW）

## 目的・制約（要件から転記・圧縮） (必須)
- 目的: コンテナ内のプロジェクトルートを `/srv/mount` 固定にせず、`/srv/mount/<project_dir>` としてプロジェクト名を保持し、ログ/状態の混線と “1段深い場所に作る” 事故を減らす。
- MUST:
  - bind mount 先を `/srv/mount/<project_dir>` にする
  - `sandbox shell` / `sandbox codex` の workdir（`docker compose exec -w` / `codex resume --cd`）を同じ基準で計算する
  - `--mount-root` / `--workdir` の入力検証（workdir must be within mount-root 等）を維持する
- MUST NOT:
  - CLI の引数やサブコマンド仕様を互換性なく変更しない
  - `PRODUCT_NAME` をインスタンスごとに変えて image build を増やさない
- 非交渉制約:
  - Bash のみで実装する（Python 依存を増やさない）
  - コンテナ内 “マウント親” は `/srv/mount` を維持する
  - `PRODUCT_NAME=mount` を維持する（ビルドキャッシュ維持）
- 前提:
  - `mount-root` はホスト側の bind mount する最上位ディレクトリ
  - `workdir` は `mount-root` 配下の作業開始ディレクトリ

---

## 既存実装/規約の調査結果（As-Is / 95%理解） (必須)
- 参照した規約/実装（根拠）:
  - `AGENTS.md`: 会話/実装ルール（日本語、禁止Git操作など）
  - `host/sandbox`: 動的起動の仕様決定（`prepare_compose_env`, `compute_container_workdir`）
  - `docker-compose.yml`: `PRODUCT_WORK_DIR` が `working_dir` と bind mount target を兼ねる
  - `tests/sandbox_cli.test.sh`, `tests/sandbox_paths.test.sh`: `/srv/mount` 固定の期待が多数
  - `@.spec-dock/current/requirement.md`: 本機能の承認済み要件（Q-001〜Q-003 決定含む）
- 観測した現状（事実）:
  - `host/sandbox` が `PRODUCT_WORK_DIR=/srv/mount` を固定で注入している（`host/sandbox:220`）。
  - `docker-compose.yml` は `working_dir: ${PRODUCT_WORK_DIR}` と `- ${SOURCE_PATH}:${PRODUCT_WORK_DIR}` を持つ（`docker-compose.yml:13,23`）。
  - `compute_container_workdir()` は `mount-root == workdir` で `/srv/mount` を返す（`host/sandbox:535-537`）。
  - 結果として典型ケースでコンテナ内ルートが常に `/srv/mount` になり、ディレクトリ名が `mount` に潰れる。
- 採用するパターン:
  - 既存の “host パス → container パス変換” を 1 箇所で集中管理する（`compute_container_workdir` 系）
  - stdout 契約（`name/status/help`）を汚さない（警告は stderr）
- 採用しない/変更しない:
  - `mount-root` 自動推定ロジック（git worktree LCA 等）は変更しない（要件 OUT OF SCOPE）
  - `PRODUCT_NAME` を可変にしてビルドキャッシュを分散させない（要件 MUST NOT）
- 影響範囲（呼び出し元/関連コンポーネント）:
  - `sandbox up|shell|codex` の compose env 注入と `exec -w` / `--cd` の算出
  - Codex trust キー（`/srv/mount/...`）が変わるため、再 Trust が必要になり得る（要件で許容）

## 主要フロー（テキスト：AC単位で短く） (任意)
- Flow for AC-001（mount-root==workdir）:
  1) `abs_mount_root` を決定
  2) `<project_dir>` を決め、`container_mount_root=/srv/mount/<project_dir>` を算出
  3) `PRODUCT_WORK_DIR=container_mount_root` を注入し compose up
  4) `container_workdir=container_mount_root` を使って `exec -w` / `codex --cd`
- Flow for AC-002（workdir が配下）:
  1) `rel = workdir - mount-root` を算出
  2) `container_workdir=container_mount_root/<rel>` を使って `exec -w` / `codex --cd`
- Flow for AC-003（up 単独）:
  1) `PRODUCT_WORK_DIR=container_mount_root` を注入して compose up
  2) サービス `working_dir=${PRODUCT_WORK_DIR}` により、コンテナの初期作業ディレクトリが `<project_dir>` 配下になる

## 判断材料/トレードオフ（Decision / Trade-offs） (任意)
- 論点: `<project_dir>` の決定規則
  - 決定: **Q-001 A（`basename(abs_mount_root)` を原則そのまま）**
  - 例外: **Q-002 A（unsafe は自動変換し、stderr 警告）**
  - 互換: **Q-003 A（破壊的変更 OK）**

## インターフェース契約（ここで固定） (任意)
### 関数・クラス境界（重要なものだけ）
- IF-001: `host/sandbox::compute_project_dir(abs_mount_root) -> project_dir`
  - Input: `abs_mount_root`（ホスト絶対パス）
  - Output: `project_dir`（コンテナ側で 1 パス要素として使う名前）
  - Error: なし（必ず何かを返す。空になる場合は `"dir"` 等へフォールバック）
  - Side effect: unsafe 変換が発生した場合は stderr に警告を 1 回出す（stdout は汚さない）
- IF-002: `host/sandbox::compute_container_mount_root(abs_mount_root) -> "/srv/mount/<project_dir>"`
  - Input: `abs_mount_root`
  - Output: コンテナ側の mount root 文字列
- IF-003: `host/sandbox::compute_container_workdir(abs_mount_root, abs_workdir) -> "/srv/mount/<project_dir>/<rel>"`
  - Input: `abs_mount_root` / `abs_workdir`（ホスト絶対パス）
  - Output: `container_workdir`
  - Error: `workdir must be within mount-root`（既存互換）
- IF-ENV-001: Compose へ注入する値（動的モード）
  - `SOURCE_PATH=<abs_mount_root>`（host 側）
  - `PRODUCT_WORK_DIR=/srv/mount/<project_dir>`（container 側: mount target かつ working_dir）
  - `PRODUCT_NAME=mount`（固定）
  - その他（`CONTAINER_NAME`, `COMPOSE_PROJECT_NAME`, `HOST_SANDBOX_PATH`, `HOST_USERNAME`, `TZ`）は現状維持

### unsafe 判定（設計で固定）
- unsafe とみなす条件（最小）:
  - `<project_dir>` に `:` を含む（compose の `host:container` 記法で壊れ得る）
  - `<project_dir>` に制御文字（`[[:cntrl:]]`）を含む（ログ/引数/設定の解釈が壊れ得る）
- 変換規則（最小・可逆は要求しない）:
  - `:` は `_` に置換する
  - 制御文字は削除する
  - 変換後に空になった場合は `"dir"` にフォールバックする
- stderr 警告（例）:
  - `sandbox: project dir "<raw>" is unsafe; using "<converted>"`

## 変更計画（ファイルパス単位） (必須)
- 追加（Add）:
  - なし
- 変更（Modify）:
  - `host/sandbox`
    - `prepare_compose_env()` の `PRODUCT_WORK_DIR` を `/srv/mount/<project_dir>` に変更
    - `compute_container_workdir()` を `/srv/mount/<project_dir>` 基準に変更
    - `<project_dir>` 算出（IF-001/002）を追加し、unsafe 変換時は stderr 警告
  - `tests/sandbox_paths.test.sh`
    - `/srv/mount` 固定の期待値を `/srv/mount/<project_dir>` に更新
  - `tests/sandbox_cli.test.sh`
    - `PRODUCT_WORK_DIR=/srv/mount` の期待値を `/srv/mount/<project_dir>` に更新
    - `docker compose exec -w /srv/mount/...` の期待値を `/srv/mount/<project_dir>/...` に更新
    - unsafe 変換（stderr 警告）を観測するテストを追加（新規 or 既存に追記）
- 削除（Delete）:
  - なし
- 移動/リネーム（Move/Rename）:
  - なし
- 参照（Read only / context）:
  - `docker-compose.yml`: `working_dir` と `volumes` が `PRODUCT_WORK_DIR` に依存しているため
  - `Dockerfile`: `/srv/mount`（親）が存在する前提のため（`PRODUCT_NAME=mount`）

## マッピング（要件 → 設計） (必須)
- AC-001 → IF-001/002/003, `host/sandbox`, `tests/sandbox_paths.test.sh`, `tests/sandbox_cli.test.sh`
- AC-002 → IF-003, `host/sandbox`, `tests/sandbox_paths.test.sh`, `tests/sandbox_cli.test.sh`
- AC-003 → IF-ENV-001, `host/sandbox`, `tests/sandbox_cli.test.sh`
- EC-001（unsafe 文字） → IF-001（unsafe 判定/変換/警告）, `tests/...`（stderr 観測）
- 非交渉制約（Bashのみ / `/srv/mount` 維持 / `PRODUCT_NAME=mount`） → `host/sandbox`（env 注入と関数実装）+ `docker-compose.yml`（`PRODUCT_NAME` build arg 維持）

## テスト戦略（最低限ここまで具体化） (任意)
- 更新するテスト:
  - `tests/sandbox_paths.test.sh`
    - `mount_root_only_sets_workdir`: `/srv/mount/<project_dir>`
    - `mount_root_and_workdir_maps_container_path`: `/srv/mount/<project_dir>/<rel>`
  - `tests/sandbox_cli.test.sh`
    - `up_injects_required_env`: `PRODUCT_WORK_DIR=/srv/mount/<project_dir>`
    - `shell_exec_w`: `exec -w /srv/mount/<project_dir>/<rel>`
    - `shell_injects_dod_env_vars`: `PRODUCT_WORK_DIR=/srv/mount/<project_dir>`
- 追加するテスト（提案）:
  - unsafe 変換:
    - `mount_root_basename_contains_colon_is_sanitized_and_warns_on_stderr`
      - mount-root: `<tmp_dir>/my:proj`（basename に `:` を含む）
      - 期待:
        - `PRODUCT_WORK_DIR=/srv/mount/my_proj`（例）
        - stderr に警告が出る
- どのAC/ECをどのテストで保証するか:
  - AC-001 → `tests/sandbox_paths.test.sh::mount_root_only_sets_workdir`, `tests/sandbox_cli.test.sh::{up_injects_required_env,shell_injects_dod_env_vars}`
  - AC-002 → `tests/sandbox_paths.test.sh::mount_root_and_workdir_maps_container_path`, `tests/sandbox_cli.test.sh::shell_exec_w`
  - EC-001 →（追加予定）unsafe 変換テスト
- 実行コマンド:
  - `bash tests/sandbox_paths.test.sh`
  - `bash tests/sandbox_cli.test.sh`
- 変更後の運用（移行メモ）:
  - 以後、コンテナ内のプロジェクトルートは `/srv/mount/<project_dir>` になる（`/srv/mount` は親ディレクトリ）。
  - Codex Trust はパスが変わるため、初回は bootstrap → Trust → 再実行が必要になり得る。

## リスク/懸念（Risks） (任意)
- R-001: `basename(mount-root)` が同名の別プロジェクトがあるとコンテナ内パスが衝突し、混線が残る可能性（要件 R-004）。対応: 運用で同名を避ける。必要なら将来 hash 付与へ拡張。
- R-002: `/srv/mount` 直下前提の手順/スクリプトが壊れる（破壊的変更を許容済み）。対応: 移行メモを残す。
- R-003: unsafe 変換の規則が意図とズレる可能性。対応: stderr 警告を出し、テストで固定する。

## 未確定事項（TBD） (必須)
- 該当なし（Q-001〜Q-003 は `@.spec-dock/current/requirement.md` で確定済み）

---

## ディレクトリ/ファイル構成図（変更点の見取り図） (任意)
```text
<repo-root>/
├── host/
│   └── sandbox                 # Modify: project_dir 算出 / PRODUCT_WORK_DIR / workdir 変換
├── docker-compose.yml          # Read only（設計時点では変更不要）
└── tests/
    ├── sandbox_paths.test.sh   # Modify: /srv/mount/<project_dir> 期待へ更新
    └── sandbox_cli.test.sh     # Modify: PRODUCT_WORK_DIR / exec -w 期待へ更新
```
