# コンテナ内マウント先が常に `mount` になる問題（As-Is分析と修正方針案）

## 1. 何が起きているか（症状）
- ホスト側のプロジェクトを `sandbox shell` / `sandbox codex` で起動すると、コンテナ内の作業ルートが常に `/srv/mount` になり、ディレクトリ名が常に `mount` になる。
- その結果、Codex CLI 等の「プロジェクト名/ルートディレクトリ名」ベースのログや状態が、複数プロジェクトで混線する。
- その結果、エージェントが現在地を `mount` と誤認し、新規プロジェクト作成時に意図より1段深い階層に作ってしまうことがある。

## 2. As-Is（コード上の根拠）
### 2.1 変数注入と mount の決まり方
- `docker-compose.yml` は以下を持つ:
  - `working_dir: ${PRODUCT_WORK_DIR}`（`docker-compose.yml:13`）
  - `- ${SOURCE_PATH}:${PRODUCT_WORK_DIR}`（`docker-compose.yml:23`）
- `host/sandbox` は `prepare_compose_env()` で `PRODUCT_WORK_DIR=/srv/mount` を固定注入している（`host/sandbox:203-224`）。
  - つまり「どのプロジェクトでも bind mount target が `/srv/mount` 固定」になっている。

### 2.2 workdir 変換（/srv/mount 固定が露出する箇所）
- `host/sandbox` の `compute_container_workdir()` は次の仕様（`host/sandbox:526-542`）:
  - `mount-root == workdir` → `/srv/mount`
  - それ以外 → `/srv/mount/<mount-rootからの相対パス>`
- 典型ケース（`--mount-root <project_root> --workdir <project_root>`）は前者なので、コンテナ内では必ず `/srv/mount` に落ちる。

## 3. To-Be（ユーザー要望の意図を “観測可能” に落とす）
ユーザー要望は「`/srv/mount` をプロジェクトルートにするのではなく、`/srv/mount` の下にプロジェクトディレクトリを作り、その中にマウントしたい」。

式で書くと:
- `container_mount_root = /srv/mount/<project_dir>`
- `container_workdir = container_mount_root + rel(workdir, mount-root)`

ここで `<project_dir>` はホスト `mount-root` から決まる名前（候補は要件の Q-001）。

## 4. 修正方針案（実装はまだしない）
### 方針A（推奨）: “マウント先” を `/srv/mount/<project_dir>` にする
- 変えるべき点（最小）:
  - `host/sandbox`:
    - `prepare_compose_env()` の `PRODUCT_WORK_DIR` を固定 `/srv/mount` から `container_mount_root` へ変更
    - `compute_container_workdir()` のベースを `/srv/mount` 固定から `container_mount_root` ベースへ変更
  - テスト:
    - `tests/sandbox_cli.test.sh` / `tests/sandbox_paths.test.sh` など、`/srv/mount` 直書き期待を更新
  - ドキュメント（必要なら）:
    - “コンテナ内ルートは `/srv/mount/<project_dir>`” に更新
- 良い点:
  - そもそもコンテナ内のディレクトリ名が `mount` に潰れない（根本原因に直接効く）
  - Codex の trust キーも `/srv/mount/<project_dir>/...` になり、プロジェクト単位に分離しやすい
- 注意点:
  - `<project_dir>` の命名（unsafe 文字/長さ）を決める必要がある（要件 Q-001/Q-002）
  - 既存運用が `/srv/mount` 直下前提だと破壊的（要件 Q-003）

### 方針B: symlink で “見かけのプロジェクト名” を作る（代替案）
- 例: `/srv/workspaces/<project>` → `/srv/mount` へ symlink を作り、`--cd` / `-w` を symlink 側へ寄せる
- 良い点:
  - compose の bind mount 形式（`${SOURCE_PATH}:${PRODUCT_WORK_DIR}`）を変えずに済む可能性
- 悪い点/不確実性:
  - Codex や git が `realpath` を取ると結局 `/srv/mount` に戻り、ログ混線が解消しない可能性がある（根治にならない）
  - symlink 作成/管理の責務が増える（entrypoint 依存や複数起動の扱い）

### 方針C: `/srv/mount/workspace/<project>` のように 2段にする（代替案）
- 例: `container_mount_root=/srv/mount/workspace/<project_dir>`
- 良い点:
  - `/srv/mount` 直下に管理用ディレクトリを作れて整理しやすい
- 悪い点:
  - 追加の階層が増える（ユーザーが期待する “/srv/mount/<project>” からズレる）

## 5. ベストプラクティス提案（設計フェーズで確定したい点）
- compose の volume は “文字列 `host:container`” だと `:` を含むパスで壊れ得るため、必要なら long syntax へ移行する（`type: bind`, `source:`, `target:`）。
- `<project_dir>` は “見た目” と “堅牢性” のバランスを取り、unsafe 文字がある場合だけ安全なフォールバック（slug/hash）を採用する。
- 変更は `host/sandbox` に閉じ、Dockerfile の build arg（`PRODUCT_NAME`）は固定のまま維持してビルドキャッシュを守る。

## 6. 次のヒアリング（要件 Q-001〜Q-003）
- `.spec-dock/current/requirement.md` の Q-001〜Q-003 への回答で、設計を確定できる。

