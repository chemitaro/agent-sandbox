---
種別: 要件定義書
機能ID: "SBX-MOUNT-PROJECT-DIR"
機能名: "コンテナ内マウント先を /srv/mount/<project> 配下にしてプロジェクト名を保持"
関連Issue: []
状態: "approved"
作成者: "Codex CLI (GPT-5)"
最終更新: "2026-01-27"
---

# SBX-MOUNT-PROJECT-DIR コンテナ内マウント先を /srv/mount/<project> 配下にしてプロジェクト名を保持 — 要件定義（WHAT / WHY）

## 目的（ユーザーに見える成果 / To-Be） (必須)
- ホスト側のプロジェクト（ディレクトリ）名が、コンテナ内でもそのまま維持される（`mount` という固定名に潰れない）。
- その結果、Codex CLI 等が生成する「プロジェクト単位の状態/ログ/キャッシュ」が、複数プロジェクト間で混線しない（※同名ディレクトリ衝突はリスクとして別途管理）。
- その結果、エージェントがカレントディレクトリ名を誤認して、意図しない階層（1段深い場所）に新規プロジェクトを作成し始める事故を減らす。

## 背景・現状（As-Is / 調査メモ） (必須)
- 現状の挙動（事実）:
  - `docker-compose.yml` は `SOURCE_PATH` を `PRODUCT_WORK_DIR` へ bind mount し、さらに `working_dir` も `PRODUCT_WORK_DIR` を使用している（`docker-compose.yml:13,23`）。
  - `host/sandbox` は `PRODUCT_WORK_DIR=/srv/mount` を固定値で注入している（`host/sandbox:220`）。
  - `host/sandbox` は `mount-root == workdir` のとき `compute_container_workdir()` が `/srv/mount` を返す（`host/sandbox:526-542`）。
  - よって、典型ケース（`--mount-root <project_root> --workdir <project_root>`）では、コンテナ内のプロジェクトルートが常に `/srv/mount`（ディレクトリ名は `mount`）になる。
- 現状の課題（困っていること）:
  - 複数プロジェクトで Codex CLI を使うと、チャットログ等が「`mount`」名の同一プロジェクトとして扱われ、1つのディレクトリに混在する。
  - 新規プロジェクト作成などで「自分の居場所」を `mount` と誤認し、意図した階層より1段深い場所にプロジェクトを作成し始めることがある。
- 再現手順（最小で）:
  1) ホストでプロジェクトルート（例: `/path/to/myproj`）へ移動し、`sandbox shell --mount-root . --workdir .` を実行する
  2) コンテナ内で `pwd` を確認すると `/srv/mount` になり、`basename "$(pwd)"` が `mount` になる
- 観測点（どこを見て確認するか）:
  - Shell: コンテナ内 `pwd` と、その `basename`
  - Codex: プロジェクト識別（ログ/状態）が `mount` に潰れていないこと
  - 自動テスト: `docker compose ...` の stub ログ（`tests/sandbox_cli.test.sh` 等）で `PRODUCT_WORK_DIR` と `exec -w` / `codex --cd` を観測する
- 実際の観測結果（貼れる範囲で）:
  - Input/Operation: `sandbox shell --mount-root <project_root> --workdir <project_root>`
  - Output/State: `PRODUCT_WORK_DIR=/srv/mount` が注入され、`docker compose exec -w /srv/mount ...` が実行される（`tests/sandbox_cli.test.sh` の期待値より）
- 情報源（ヒアリング/調査の根拠）:
  - ヒアリング: ユーザー申告（本スレッドの問題説明）
  - コード:
    - `host/sandbox`（`prepare_compose_env()` / `compute_container_workdir()` が仕様を決めている）
    - `docker-compose.yml`（`PRODUCT_WORK_DIR` が mount target と working_dir の両方を決めている）
  - テスト:
    - `tests/sandbox_cli.test.sh`（`PRODUCT_WORK_DIR=/srv/mount` の注入と、`exec -w /srv/mount...` の期待）

## 対象ユーザー / 利用シナリオ (任意)
- 主な利用者（ロール）:
  - 複数のプロジェクトを横断してコーディングエージェント（Codex/Claude 等）を使う開発者
- 代表的なシナリオ:
  - 既存プロジェクト A / B を同一 sandbox 環境で切り替えながら作業する（ログ/状態が混ざらないことが重要）
  - `sandbox shell` で対象プロジェクトに入り、そこを起点に新規プロジェクト（ディレクトリ）を作成する

## スコープ（暴走防止のガードレール） (必須)
- MUST（必ずやる）:
  - コンテナ内の bind mount 先を `/srv/mount/<project_dir>` 形式にし、`<project_dir>` が一意に決まるルールを導入する
  - `sandbox shell` / `sandbox codex` が使用するコンテナ内 `workdir`（`docker compose exec -w` および `codex resume --cd`）も、新しいマウント先を基準に一貫して計算する
  - `--mount-root` / `--workdir` の入力検証（`workdir must be within mount-root` 等）は現状互換で維持する
- MUST NOT（絶対にやらない／追加しない）:
  - CLI のサブコマンド/引数仕様（`--mount-root` / `--workdir` 等）を互換性なく変更しない
  - `PRODUCT_NAME` をインスタンスごとに変えて image build を増やす（ビルドキャッシュを分散させる）方向へ寄せない
- OUT OF SCOPE（今回やらない）:
  - Codex/各エージェントが生成するログ保存仕様そのものの変更（本件は「パス/ディレクトリ名の見え方」を直す）
  - 既存の `mount-root` 自動推定ロジック（git worktree LCA 等）のアルゴリズム変更

## 非交渉制約（守るべき制約） (必須)
- Bash のみで実装する（`host/sandbox` は Python 等へ依存しない）。
- コンテナ内のベースとなる “マウント親” は `/srv/mount` を維持する（「/srv/mount 配下にプロジェクトを置く」方針）。
- build arg の `PRODUCT_NAME` は固定値（現行: `mount`）のままにする（ビルドキャッシュの分散を避ける）。

## 前提（Assumptions） (必須)
- `--mount-root` は既存通りホスト側の “マウントする最上位ディレクトリ” を指す。
- `--workdir` は `--mount-root` 配下であり、作業開始位置を指す。
- コンテナ内の “プロジェクト識別” は主に「パス（ディレクトリ名）」に影響される（Codex のログ/状態の切り方に依存）。

## 判断材料/トレードオフ（Decision / Trade-offs） (任意)
- 論点: `/srv/mount/<project_dir>` の `<project_dir>` を何で決めるか
  - 選択肢A: `basename(abs_mount_root)` をそのまま使う
    - Pros: “ホストのプロジェクト名と同じ” になり、理解しやすい
    - Cons: `:` 等の文字が含まれると compose の `host:container` 形式で問題が出る可能性
  - 選択肢B: `basename(abs_mount_root)` を slug 化して使う（`normalize_slug` 相当）
    - Pros: 安全なパス要素になりやすい
    - Cons: “ホストと同じ名前” ではなくなり、ユーザーが期待する見え方とズレる
  - 選択肢C: `slug + hash`（`compute_hash12`）で決める
    - Pros: 安全・安定・衝突しにくい
    - Cons: 人間にとっての可読性が落ちる
  - 決定: **A（basename を原則そのまま）**
  - 補足（例外）: unsafe な名前は **自動で安全名へ変換**し、stderr に警告を出す（Q-002）
  - 理由: ユーザー要望（ホストのプロジェクト名をそのまま見せたい）を優先する

## リスク/懸念（Risks） (任意)
- R-001: コンテナ内のパスが変わることで、既存の手順やスクリプトが `/srv/mount` 直下前提だと壊れる可能性（影響: 手動運用 / docs / 自動化 / 対応: 変更点を明文化し、必要なら移行ガイドを用意）
- R-002: `<project_dir>` が unsafe 文字を含む場合に compose が壊れる可能性（影響: 起動不能 / 対応: 命名ルール or compose 側 long syntax へ移行）
- R-003: Codex の Trust キー（`/srv/mount/...`）が変わり、再 Trust が必要になる可能性（影響: `sandbox codex` が bootstrap になりやすい / 対応: 既存 trust の継承可否を確認し、必要なら移行手順を提供）
- R-004: `basename(mount-root)` が同名の別プロジェクトがある場合、コンテナ内パスが同一（`/srv/mount/<same>`）になり、Codex のログ/Trust 等が混線する可能性（影響: 目的の一部が満たせない / 対応: 運用で同名を避ける、または将来 `hash` 付与を検討）

## 受け入れ条件（観測可能な振る舞い） (必須)
- AC-001:
  - Actor/Role: 開発者
  - Given: `--mount-root` と `--workdir` が同一（典型ケース: プロジェクトルートをそのまま指定）
  - When: `sandbox shell` または `sandbox codex` を実行する
  - Then: コンテナ内の作業開始ディレクトリが `/srv/mount/<project_dir>` となり、`basename(pwd)` が `mount` ではなく `<project_dir>` になる
  - 観測点（UI/HTTP/DB/Log など）: Shell `pwd` / `docker compose exec -w` のパス / `codex resume --cd` のパス（stubログ）
  - 権限/認可条件（ある場合）: 該当なし
- AC-002:
  - Actor/Role: 開発者
  - Given: `--workdir` が `--mount-root` の配下（例: `<mount_root>/sub/dir`）
  - When: `sandbox shell` または `sandbox codex` を実行する
  - Then: コンテナ内の作業開始ディレクトリが `/srv/mount/<project_dir>/sub/dir` となる（`sub/dir` は `mount-root` からの相対パス）
  - 観測点（UI/HTTP/DB/Log など）: Shell `pwd` / `docker compose exec -w` のパス / `codex resume --cd` のパス（stubログ）
  - 権限/認可条件（ある場合）: 該当なし
- AC-003:
  - Actor/Role: 開発者
  - Given: `sandbox up` を使用する（`shell/codex` より前に `up` を単独で呼ぶケース）
  - When: `sandbox up --mount-root <mount_root> --workdir <workdir>` を実行する
  - Then: コンテナの `working_dir`（= `PRODUCT_WORK_DIR`）が `/srv/mount/<project_dir>` を指し、`docker compose` の bind mount target も同一になる
  - 観測点（UI/HTTP/DB/Log など）: `docker-compose.yml` の `working_dir` と `volumes` の実効値（stubログ）
  - 権限/認可条件（ある場合）: 該当なし

### 入力→出力例 (任意)
- EX-001:
  - Input:
    - mount-root: `/Users/me/work/myproj`
    - workdir: `/Users/me/work/myproj`
  - Output:
    - container workdir: `/srv/mount/myproj`
- EX-002:
  - Input:
    - mount-root: `/Users/me/work/myproj`
    - workdir: `/Users/me/work/myproj/service/api`
  - Output:
    - container workdir: `/srv/mount/myproj/service/api`

## 例外・エッジケース（仕様として固定） (必須)
- EC-001:
  - 条件: `<project_dir>` に unsafe 文字（例: `:` / 改行）や極端に長い名前が含まれる
  - 期待:
    - 起動は継続する（安全な変換ルールで `<project_dir>` を決める）
    - stderr に “変換が発生した” 警告を出す（stdout 契約を汚さない）
  - 観測点（UI/HTTP/DB/Log など）: `sandbox shell/up/codex` の stderr と終了コード、stubログ
- EC-002:
  - 条件: `--workdir` が `--mount-root` の外
  - 期待: 現状互換で失敗する（`workdir must be within mount-root`）
  - 観測点: stderr と終了コード

## 用語（ドメイン語彙） (必須)
- TERM-001: `mount-root` = ホスト側で bind mount する最上位ディレクトリ（`--mount-root`）
- TERM-002: `workdir` = ホスト側の作業開始ディレクトリ（`--workdir`、`mount-root` 配下）
- TERM-003: `container_mount_root` = コンテナ側で `mount-root` が見えるパス（To-Be: `/srv/mount/<project_dir>`）
- TERM-004: `container_workdir` = コンテナ側で `workdir` が見えるパス（`container_mount_root` + 相対パス）
- TERM-005: `<project_dir>` = `container_mount_root` 直下のディレクトリ名（`mount-root` から決定）

## 未確定事項（TBD / 要確認） (必須)
- Q-001:
  - 質問: `<project_dir>` は何で決めますか？（“ホストの名前そのまま” を最優先にするか）
  - 選択肢:
    - A: `basename(abs_mount_root)` をそのまま使う（最大限そのまま）
    - B: `basename(abs_mount_root)` を slug 化する（安全優先）
    - C: `slug + hash`（安全 + 安定 + 衝突回避）
  - 決定: **A（採用）**
  - 補足: unsafe の場合は Q-002 に従い自動変換
  - 影響範囲: AC-001/002/003, EC-001, 運用（同名衝突の可能性）
- Q-002:
  - 質問: unsafe な名前（例: `:` を含む）を検出した場合、どう振る舞うのが良いですか？
  - 選択肢:
    - A: 自動で安全な名前へ変換（slug 化 or hash）
    - B: 明確なエラーで落とす（ユーザーにディレクトリ名変更/別オプションを促す）
  - 決定: **A（採用）**
  - 補足: 変換が発生した場合は **stderr 警告を出す（Yes）**
  - 影響範囲: EC-001, 実装方針（compose long syntax 採用可否）
- Q-003:
  - 質問: 既存運用の互換性（`/srv/mount` 直下がプロジェクトルートである前提）について、移行は “破壊的変更 OK” ですか？
  - 選択肢:
    - A: 破壊的変更 OK（ドキュメント/テスト/手順を更新し、移行メモのみ用意）
    - B: 互換レイヤが必要（旧パスでも動く導線を残す）
  - 決定: **A（採用）**
  - 影響範囲: 既存手順、テスト、ユーザーのローカル設定（Codex trust 等）

## 完了条件（Definition of Done） (必須)
- すべてのAC/ECが満たされる
- 未確定事項が解消される（残す場合は「残す理由」と「合意」を明記）
- MUST NOT / OUT OF SCOPE を破っていない（追加機能を入れていない）

## 省略/例外メモ (必須)
- 該当なし
