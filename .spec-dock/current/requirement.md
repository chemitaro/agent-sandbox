---
種別: 要件定義書
機能ID: "FEAT-005"
機能名: "動的マウント起動（任意ディレクトリをSandboxとして起動）"
関連Issue: ["https://github.com/chemitaro/agent-sandbox/issues/5"]
状態: "approved"
作成者: "Codex CLI"
最終更新: "2026-01-22"
---

# FEAT-005 動的マウント起動（任意ディレクトリをSandboxとして起動） — 要件定義（WHAT / WHY）

## 目的（ユーザーに見える成果 / To-Be） (必須)
- このリポジトリ（`agent-sandbox`）をプロジェクトごとに clone せずに、任意のディレクトリを作業対象としてコンテナを起動できる。
- 引数指定なしの場合は、実行時のカレントディレクトリ（PWD）を初期作業ディレクトリとしつつ、git worktree を含む作業範囲を自動推定してマウントできる。
- 異なる作業ディレクトリ（およびマウント親）を対象に、複数コンテナを同時に起動・共存できる。
- 既存の Docker-on-Docker（sandbox コンテナ内からホスト Docker を操作する）運用が継続できる。

## 背景・現状（As-Is / 調査メモ） (必須)
- 現状の挙動（事実）:
  - `sandbox.config` の `SOURCE_PATH` / `PRODUCT_NAME` を前提に `.env` を生成し、`docker-compose.yml` が `${SOURCE_PATH}` を `${PRODUCT_WORK_DIR}` に bind mount する（= 1プロダクト前提の運用になりやすい）。
  - `make start` / `make shell` は `.env` の `PRODUCT_WORK_DIR` に `docker-compose exec -w` で入る（= `PRODUCT_WORK_DIR` が “初期作業ディレクトリ” と “DoDの変換基準” を兼ねている）。
  - `.env` はリポジトリ単位で 1つ（上書き生成）であり、同一 clone で複数プロダクト/複数コンテナを安定して並行運用しづらい。
  - Docker-on-Docker:
    - `/var/run/docker.sock` をマウントし、コンテナ内からホストの Docker を操作できる。
    - エントリポイントで docker.sock の権限調整を行い、`node` ユーザーで Docker CLI を使えるようにしている。
    - 利用ガイドで “ホスト側の絶対パスを volume mount に使う” 注意点が明記されている。
  - Devcontainer:
    - `.devcontainer/devcontainer-template.json` を元に `.devcontainer/devcontainer.json` を生成している（`workspaceFolder` を差し替え）。
- As-Is の根拠（コード観測 / 行番号つき・抜粋）:
  - `.env` 生成:
    - `.env` の出力先はリポジトリ直下固定（上書き）: `scripts/generate-env.sh:15-16`
    - `HOST_PRODUCT_PATH` は `SOURCE_PATH` を元に `.env` に出力: `scripts/generate-env.sh:149-154`
    - `PRODUCT_WORK_DIR=/srv/$product_name` を `.env` に出力: `scripts/generate-env.sh:155-161`
    - `CONTAINER_NAME` は `SOURCE_PATH` 由来で生成（最大63文字へ切り詰め）: `scripts/generate-env.sh:71-103`, `scripts/generate-env.sh:163-170`
    - `.devcontainer/devcontainer.json` はテンプレの `workspaceFolder` を `PRODUCT_WORK_DIR` に置換して生成: `scripts/generate-env.sh:214-236`, `.devcontainer/devcontainer-template.json:5-9`
  - Compose 定義（`docker-compose.yml`）:
    - Composeプロジェクト名: `name: ${CONTAINER_NAME:-agent-sandbox}`: `docker-compose.yml:1`
    - コンテナ名: `container_name: ${CONTAINER_NAME:-agent-sandbox}`: `docker-compose.yml:11`
    - 作業ディレクトリ: `working_dir: ${PRODUCT_WORK_DIR}`: `docker-compose.yml:13`
    - DoD向け環境変数:
      - `HOST_PRODUCT_PATH=${SOURCE_PATH}`: `docker-compose.yml:31`
      - `PRODUCT_WORK_DIR=${PRODUCT_WORK_DIR}`: `docker-compose.yml:33`
      - `DOCKER_HOST=unix:///var/run/docker.sock`: `docker-compose.yml:34`
    - プロダクトコードの bind mount: `${SOURCE_PATH}:${PRODUCT_WORK_DIR}`: `docker-compose.yml:37`
    - docker.sock の mount: `/var/run/docker.sock:/var/run/docker.sock`: `docker-compose.yml:48`
    - `.env` の読み込み: `env_file: .env`: `docker-compose.yml:54-55`
  - `make start` / `make shell` の挙動:
    - `make start` は `.env` の `CONTAINER_NAME` を見て起動有無を判定: `Makefile:86-105`
    - `make start` は `.env` の `PRODUCT_WORK_DIR` を `docker-compose exec -w` に渡して接続: `Makefile:109-113`
  - docker-entrypoint（DoD権限調整）:
    - docker.sock のGID取得・dockerグループ調整・nodeユーザーへ付与: `scripts/docker-entrypoint.sh:5-25`
    - 起動時に `docker version` で疎通確認: `scripts/docker-entrypoint.sh:55-60`
  - 外部プロダクトの依存（`taikyohiyou_project`）:
    - `HOST_PRODUCT_PATH` と `PRODUCT_WORK_DIR` が与えられる場合、コンテナ内パス（`repo_root`）を “ホスト絶対パス” に変換して `.env.git` に書き出す: `/Users/iwasawayuuta/workspace/product/taikyohiyou_project/scripts/git/detect_git_env.sh:15-25`, 同 `:66-78`
- 現状の課題（困っていること）:
  - 別プロジェクトで使うには `sandbox.config` の書き換え、または sandbox をプロジェクトごとに clone する必要がある。
  - 「どのディレクトリでも」安全にエージェントを動かすための汎用 sandbox として使いにくい。
- 再現手順（最小で）:
  1) `sandbox.config` にプロジェクトAの `SOURCE_PATH` を設定し `make start` する
  2) プロジェクトBに切り替えたい場合、`sandbox.config` を編集して再起動する（または別 clone を用意する）
- 観測点（どこを見て確認するか）:
  - Host: 起動コマンドの出力（選ばれた mount-root / workdir / コンテナ名）
  - Docker: `docker ps` / OrbStack 等の UI でコンテナが識別できること
  - Container: 起動直後の `pwd` が期待通りであること、対象ディレクトリ配下が参照できること
- 情報源（ヒアリング/調査の根拠）:
  - Issue: `https://github.com/chemitaro/agent-sandbox/issues/5`
  - ドキュメント: `README.md`, `CLAUDE.md`
  - コード: `scripts/generate-env.sh`, `docker-compose.yml`, `Makefile`
  - ヒアリング: ユーザー要望（Q-001〜Q-005に回答済み）

## 対象ユーザー / 利用シナリオ (任意)
- 主な利用者（ロール）:
  - ホスト環境からコンテナを立ち上げ、Claude/Codex/Gemini/OpenCode などを動かす開発者
  - OrbStack / Docker Desktop 等の UI でコンテナを手動停止/削除したい開発者
- 代表的なシナリオ:
  - 任意のリポジトリ（または git worktree）ディレクトリでコマンドを実行し、その場所を初期ディレクトリとして sandbox を起動する
  - 複数の worktree を並行して別コンテナで起動し、別セッションで同時作業する

## スコープ（暴走防止のガードレール） (必須)
- MUST（必ずやる）:
  - 新しい起動スクリプト（ホスト側）を追加し、任意ディレクトリから sandbox を起動できるようにする。
    - `/usr/local/bin/sandbox` に symlink を配置するインストール手段を提供する（本体は置かない）。
  - `mount-root`（マウント親）と `workdir`（初期作業ディレクトリ）を分離して扱えるようにする。
    - 両方指定された場合は指定通りに採用する。
    - `--mount-root` のみ指定された場合は `workdir=mount-root` に補完する。
    - `--workdir` のみ指定された場合は git を解析して `mount-root` を自動推定する（非gitなら `mount-root=workdir`）。
    - 何も指定しない場合は `workdir=PWD` とし、git を解析して `mount-root` を自動推定する。
    - git 管理外ディレクトリの場合は `mount-root=workdir=PWD` とする。
  - git worktree に対応する:
    - `mount-root` は “main + 全 worktree を包含するディレクトリ” を自動推定できること（ただしガードあり）。
    - 初期作業ディレクトリは PWD（または指定）に一致すること。
  - 複数コンテナを同時に起動可能にする:
    - コンテナの同一性キーは `(abs_mount_root, abs_workdir)` とする（両方 realpath/絶対パス化）。
    - 同一性キーが異なれば別コンテナとして起動する（並行稼働できる）。
  - **動的マウント起動モード**のコンテナ内マウント先（mount point）は固定値とし、`/srv/mount` を採用する。
  - コンテナ名は自動生成のみ（ユーザー指定は不要）:
    - prefix: `sandbox-`
    - 可読部: `basename(mount-root)` + `basename(workdir)`（同一の場合は重複しない）
    - 末尾: 衝突防止のハッシュ（12桁固定）
  - Docker-on-Docker 運用を維持する:
    - sandbox コンテナ内からホスト Docker を操作できること（docker.sock マウント/権限調整の維持）
    - 既存の Docker-on-Docker を使うプロダクト（例: `/Users/iwasawayuuta/workspace/product/taikyohiyou_project`）で従来通り動くこと
    - Docker-on-Docker での “コンテナ内パス → ホストパス” 変換に必要な環境変数を維持する（`HOST_PRODUCT_PATH` と `PRODUCT_WORK_DIR`）。
  - 生成/保持ファイルを増やさない:
    - コンテナごとに `.env` や docker-compose yaml、Dockerfile を生成して保持しない。
    - 1つの `docker-compose.yml` を使い回し、インスタンス固有値は起動コマンド実行時に注入する。
    - `.env` は secrets/common の静的ファイルとしてユーザーが管理し、ツールは自動生成/上書きしない。
- MUST NOT（絶対にやらない／追加しない）:
  - コンテナ名の手動指定機能（`--name` 等）は追加しない。
  - “広すぎる” `mount-root` を自動推定した場合、無理に包含しない（エラーで拒否する）。
  - 既存のセキュリティ特性（非root実行、ネットワーク制限等）を緩めない。
  - Devcontainer（VS Code Remote Containers）のために、動的マウント/複数コンテナの仕様・設計を複雑化しない。
- OUT OF SCOPE（今回やらない）:
  - `.agent-home`（各CLIの設定/履歴/キャッシュ）をインスタンスごとに分離する機能（必要なら後続で検討）。
  - 複数マウント（追加パス）や ro/rw 指定などの高度なマウント機能。
  - Homebrew/npm などでの配布（インストール）まで含めた整備。
  - Devcontainer の追従（特に「動的マウント/複数コンテナ」モードに合わせた `.devcontainer/devcontainer.json` 自動更新や、複数インスタンス対応）。
  - 旧 `sandbox.config` / `scripts/generate-env.sh` / `make start` / `make shell` フローの互換性維持（= 旧フローを残したまま同等に動くことの保証）。

## 非交渉制約（守るべき制約） (必須)
- **動的マウント起動モード**のコンテナ内マウント先は固定: `/srv/mount`。
- `mount-root` 自動推定にガードを入れ、広すぎる場合はエラーで拒否する（安全優先）。
- コンテナ名は ASCII で扱える文字（`sandbox-...`）で自動生成する。
- コンテナ名の末尾ハッシュは 12桁固定とする。
- `.agent-home`（各CLIの設定/履歴/キャッシュ）は既存通り共有する（インスタンスごとに分離しない）。
- Docker-on-Docker を壊さない（`docker` CLI が使え、ホストパスで volume mount できる前提を維持する）。
- 追加の yaml/ Dockerfile をインスタンスごとに生成して保存しない（運用負荷を増やさない）。

## 前提（Assumptions） (必須)
- ホスト側で `docker` / `docker compose` が利用できる。
- 対象のディレクトリはローカルファイルシステム上に存在し、ホストから bind mount できる。
- git worktree は “極端に離れた場所” に配置しない運用が基本である（離れている場合は拒否してよい）。

## 判断材料/トレードオフ（Decision / Trade-offs） (任意)
- 論点: `mount-root` の自動推定（便利さ） vs 事故防止（安全さ）
  - 決定: 自動推定は行うが、広すぎる場合は拒否（エラー）
  - 理由: 意図しない巨大マウントはリスクが高く、運用としても避けたい
- 論点: 複数インスタンスの共存（並行性） vs 生成物増加（運用負荷）
  - 決定: インスタンスごとに `.env` / yaml を生成・保持せず、起動時の環境変数注入で分離する
  - 理由: 生成物が増えると管理不能になるため

## リスク/懸念（Risks） (任意)
- R-001: `mount-root` 自動推定の誤判定（過度に広い/狭い）
  - 影響: 起動失敗、または意図しない範囲のマウント
  - 対応: ガードで拒否し、明示指定手段（`--mount-root`）を提供する（詳細は design で固定）
- R-002: パスに空白や記号が含まれる場合の取り扱い
  - 影響: コマンド実行や compose 変数展開で失敗
  - 対応: 実装で安全な quoting/realpath を徹底し、テストで担保する

## 受け入れ条件（観測可能な振る舞い） (必須)
- AC-001: 引数なし起動（git worktree 自動推定）
  - Actor/Role: 開発者
  - Given: git 管理下のディレクトリ（worktree を含む可能性あり）で PWD が作業対象である
  - When: 新しい起動スクリプトを引数なしで実行する
  - Then:
    - `workdir` は PWD が採用される
    - `mount-root` は git 情報を解析して自動推定される（worktree を包含）
    - コンテナが起動し、初期作業ディレクトリが PWD 相当のパスになる
  - 観測点:
    - Host 出力: `mount-root` / `workdir` / コンテナ名が表示される
    - Container: `pwd` が期待通り
- AC-002: 明示指定起動（mount-root/workdir）
  - Actor/Role: 開発者
  - Given: `--mount-root` と `--workdir` に実在するディレクトリを指定できる
  - When: 起動スクリプトに両方を指定して実行する
  - Then:
    - 指定した `mount-root` が `/srv/mount` にマウントされる
    - 指定した `workdir` に対応するコンテナ内パスに初期移動する
  - 観測点:
    - Container: 指定した `workdir` に対応する `pwd` になっている
- AC-003: 複数インスタンスの並行起動
  - Actor/Role: 開発者
  - Given: 異なる `(mount-root, workdir)` の組が2つ以上ある
  - When: それぞれで起動スクリプトを実行する
  - Then: 別コンテナとして同時に起動・共存できる（片方がもう片方を落とさない）
  - 観測点: `docker ps` / OrbStack UI で複数コンテナが確認できる
- AC-004: コンテナ名の自動生成（可読 + 衝突防止）
  - Actor/Role: 開発者
  - Given: 起動スクリプトが `mount-root/workdir` を確定できる
  - When: コンテナを起動する
  - Then:
    - コンテナ名が `sandbox-` で始まる
    - `basename(mount-root)` と `basename(workdir)` の可読部が含まれる（同一の場合は重複しない）
    - 末尾に 12桁ハッシュが付与され、衝突しにくい
    - 12桁ハッシュは **instance key（`abs_mount_root` と `abs_workdir` のフルパス）** から算出する（可読部の短縮形/slugからは算出しない）
    - 同一 instance key（`(abs_mount_root, abs_workdir)`）なら、同一コンテナ名になる（決定的）
  - 観測点: `docker ps` / OrbStack UI で識別できる
- AC-005: 自動推定が “広すぎる” 場合は拒否
  - Actor/Role: 開発者
  - Given: 自動推定すると `mount-root` が過度に広くなるケース（意図しない巨大マウントにつながる）
  - When: 引数なし起動を試みる
  - Then:
    - エラーで終了し、`--mount-root` などの明示指定を促す
    - 具体的には、以下のいずれかに該当する場合は “広すぎる” と判定して拒否する
      - 禁止パス（完全一致）: `/`, `$HOME`, `/Users`, `/home`, `/Volumes`, `/mnt`, `/media`
      - `git rev-parse --show-toplevel`（= repo root）から `mount-root` までの遡り階層数が **1 を超える**
        - 例: `repo_root=/a/b/repo` のとき、`mount-root=/a/b`（遡り=1）は許容し、`mount-root=/a`（遡り=2）は拒否する
  - 観測点: Host 出力（エラーメッセージ、終了コード）
- AC-006: （削除）既存運用の互換性
  - メモ: ユーザー合意により、旧 `sandbox.config` / `make start` フローの互換性は要求しない（OUT OF SCOPE）。
- AC-007: 引数なし起動（git 管理外ディレクトリ）
  - Actor/Role: 開発者
  - Given: git 管理外のディレクトリで PWD が作業対象である
  - When: 新しい起動スクリプトを引数なしで実行する
  - Then:
    - `mount-root=workdir=PWD` が採用される
    - コンテナが起動し、初期作業ディレクトリが PWD 相当のパスになる
  - 観測点:
    - Host 出力: `mount-root` / `workdir` / コンテナ名が表示される
    - Container: `pwd` が期待通り
- AC-008: インストール（symlink）
  - Actor/Role: 開発者
  - Given: sandbox リポジトリがローカルに存在する
  - When:
    - インストール手段を実行する
  - Then:
    - `/usr/local/bin/sandbox` に起動スクリプトへの symlink が作成される
    - そのコマンドが任意ディレクトリから実行できる
  - 観測点:
    - Host: `ls -l /usr/local/bin/sandbox`（symlinkであること）
    - Host: 任意ディレクトリでの起動が成功する
- AC-009: Docker-on-Docker が利用できる
  - Actor/Role: 開発者
  - Given: ホストに Docker があり、sandbox コンテナが `/var/run/docker.sock` をマウントして起動している
  - When: sandbox コンテナ内で Docker CLI を実行する（例: `docker version`）
  - Then: 失敗せずに実行できる
  - 観測点: Container 内コマンド結果
- AC-010: Docker-on-Docker のホストパス変換が成り立つ
  - Actor/Role: 開発者
  - Given:
    - `HOST_PRODUCT_PATH=<mount-root host absolute path>` と `PRODUCT_WORK_DIR=/srv/mount` が sandbox コンテナに設定されている
    - 例: `/Users/iwasawayuuta/workspace/product/taikyohiyou_project` のように、sandbox 内で Docker-on-Docker を行うプロダクトが存在する
  - When: sandbox コンテナ内で対象プロダクトの “コンテナ内パス→ホストパス変換” を行うスクリプトを実行する（例: `taikyohiyou_project/scripts/git/detect_git_env.sh`）
  - Then: 変換後のパス（例: `.env.git` の `CURRENT_PROJECT_PATH`）がホストから見える絶対パスになる
  - 観測点: Container 内のスクリプト出力/生成ファイル
- AC-011: 同一 instance key の再実行でコンテナが増えない（再利用）
  - Actor/Role: 開発者
  - Given: 同一の `(abs_mount_root, abs_workdir)` で動的マウント起動を実行できる
  - When: 同じ引数（または同じ PWD からの引数なし起動）で複数回起動する
  - Then:
    - 同一コンテナ名が選ばれ、コンテナが “増殖” しない
    - 既に存在するが停止中の場合は、そのコンテナが再起動される
  - 観測点: `docker ps -a` の名前一覧 / OrbStack UI 上のコンテナ数

### 入力→出力例 (任意)
- EX-001: 引数なし（worktree内）
  - Input: `pwd=/path/to/repo/worktrees/feature-a` で起動スクリプト実行
  - Output:
    - `mount-root=/path/to/repo`（例。実際は自動推定）
    - Container: `/srv/mount/worktrees/feature-a` に入る
- EX-002: 明示指定
  - Input: `--mount-root /path/to/repo --workdir /path/to/repo/worktrees/feature-a`
  - Output: Container: `/srv/mount/worktrees/feature-a`

## 例外・エッジケース（仕様として固定） (必須)
- EC-001: `workdir` が `mount-root` 配下ではない
  - 条件: `--mount-root` と `--workdir` を両方指定し、`workdir` が `mount-root` の外にある
  - 期待: エラーで終了し、どの条件に違反したかが明確なメッセージを出す
  - 観測点: Host 出力 / 終了コード
- EC-002: パスに空白を含む
  - 条件: `mount-root` または `workdir` に空白が含まれる
  - 期待: 正しく解釈され、起動・接続できる（またはサポート外なら明確にエラー）
  - 観測点: Host 出力 / Container `pwd`
- EC-003: git 判定/解析に失敗
  - 条件: git 管理下のはずのディレクトリで `git` コマンドが失敗する、または worktree 情報が取得できない
  - 期待: エラーで終了し、明示指定（`--mount-root`/`--workdir`）を促す
  - 観測点: Host 出力 / 終了コード
- EC-004: コンテナ名の可読部（slug）に不正/長すぎる文字が含まれる
  - 条件: `basename(mount-root)` / `basename(workdir)` に非ASCII、空白、記号が含まれる、または極端に長い
  - 期待:
    - コンテナ名は Docker が受理できる文字種に正規化される（少なくとも ASCII に落とす）
    - コンテナ名（全体）は Docker/Compose の制約を超えない長さに収める（例: 63文字程度）
    - 正規化の結果可読部が空になる場合でも、起動不能にならない（fallback で最低限の名前を確保）
  - 観測点: Host 出力 / `docker ps` の名前表示 / 起動成功

## 用語（ドメイン語彙） (必須)
- TERM-001: mount-root = ホスト側で bind mount する “親ディレクトリ”（動的マウント起動モードで、コンテナ内 `/srv/mount` に載る）
- TERM-002: workdir = コンテナ起動後に最初に入る作業ディレクトリ（PWD 由来 or 指定）
- TERM-003: instance key = `(abs_mount_root, abs_workdir)`（realpath/絶対パス）で表すコンテナ同一性
- TERM-004: slug = コンテナ名に含める可読部（`basename(mount-root)` と `basename(workdir)` の組）
- TERM-005: `PRODUCT_WORK_DIR` = Docker-on-Docker 用の “コンテナ内” マウント基準パス（= `HOST_PRODUCT_PATH` に対応するコンテナ内の基準パス）
  - 本機能: `/srv/mount`
- TERM-006: `HOST_PRODUCT_PATH` = Docker-on-Docker 用の “ホスト側” マウント基準パス（= `PRODUCT_WORK_DIR` に対応するホスト絶対パス）
  - 本機能: `abs_mount_root`

## 未確定事項（TBD / 要確認） (必須)
- 該当なし（Q-003 は 2026-01-22 に確定）

## 完了条件（Definition of Done） (必須)
- すべてのAC/ECが満たされる
- 未確定事項が解消される（残す場合は「残す理由」と「合意」を明記）
- MUST NOT / OUT OF SCOPE を破っていない（追加機能を入れていない）

## 省略/例外メモ (必須)
- 該当なし
