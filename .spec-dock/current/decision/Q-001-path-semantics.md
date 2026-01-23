# Q-001: `--path` の意味をどう定義するか（workdir / mount root）

## この質問の意図（なぜ決める必要があるか）
この機能の核心は「ホスト側の任意パスを、コンテナ内ワークスペースとしてマウントして起動する」ことです。  
そのとき `--path` が **何を指すのか** を最初に固定しないと、以下が曖昧になります。

- どのホストパスを bind mount するか（= mount root）
- コンテナの `working_dir` をどこにするか（= workdir / 初期作業ディレクトリ）
- git worktree 対応のために “親を大きくマウント” したい要件と、“最初は今いるディレクトリから作業したい” という UX をどう両立するか
- `.env` 生成や `docker-compose` 実行のインターフェースがブレる（設計・テスト対象が増える）

現状の repo は `sandbox.config` の `SOURCE_PATH`（=マウント元）と `PRODUCT_WORK_DIR`（=コンテナ内の作業場所）を同一視しやすい構造です（`docker-compose.yml` の `${SOURCE_PATH}:${PRODUCT_WORK_DIR}`、`Makefile` の `-w $$PRODUCT_WORK_DIR`）。  
今回 “マウントする親” と “作業開始ディレクトリ” を分離するなら、**ここで用語と旗を分ける** のが重要です。

## 用語（このシート内の定義）
- **workdir（初期作業ディレクトリ）**: コンテナ起動後に最初に入るディレクトリ。例: `docker-compose exec -w ...`
- **mount root（マウント親）**: ホスト側で bind mount する起点パス。例: `- ${MOUNT_ROOT}:${CONTAINER_MOUNT_POINT}`
- **container mount point（コンテナ内マウント先）**: mount root が載るコンテナ内パス。例: `/srv/workspace`

## 選択肢

### A) `--path` = workdir（初期作業ディレクトリ）
**定義**: `--path` は「コンテナが最初に `cd` する場所」を表す。mount root は別ロジックで自動推定（または暗黙に workdir と同じ扱い）。

**メリット**
- UX が直感的: “ここで作業したい” をそのまま指定できる（または `--path` 省略時は PWD で自然）
- `--path` 省略時（PWD利用）と整合しやすい

**デメリット**
- mount root を自動推定する必要がある（git worktree を含むため難しい）
  - 推定ミス = “必要なファイルが見えない” or “意図せず広いディレクトリをマウント” のどちらかになりがち
- `--path` が workdir なのに mount root が別、という仕様を説明しないと混乱しやすい

**向いているケース**
- worktree 対応を薄めにし、「基本は単一ディレクトリをマウント」運用を主にする場合

---

### B) `--path` = mount root（マウント親）
**定義**: `--path` は「ホスト側の bind mount の起点」。workdir は常に mount root（または固定値）。

**メリット**
- 実装が単純になりやすい（`SOURCE_PATH` 相当が 1値に定まる）
- worktree “親を大きくマウント” 要件と相性が良い

**デメリット**
- “今いるディレクトリから作業開始したい” という UX を満たすには別フラグ/別機構が必要
- 省略時 PWD を mount root にすると、worktree 全体を包含できず要件に不足する可能性がある（worktree が別場所にある場合）

**向いているケース**
- 常に「親を指定する」運用に割り切る（workdir も親固定で良い）場合

---

### C) `--path` = workdir、`--mount-root` を別フラグとして用意（省略時は自動推定）
**定義**:
- `--path`（省略時は PWD）= 初期作業ディレクトリ（workdir）
- `--mount-root`（省略可）= bind mount の起点（mount root）
- `--mount-root` 省略時は、git 情報等から “安全な” 親を自動推定する（詳細は Q-002）

**メリット**
- 要件（worktree 親マウント + 作業開始は PWD）を **素直に表現** できる
- 自動推定の失敗時も `--mount-root` で明示的に逃げられる（運用で詰まりにくい）
- テスト観点が明確: `--path` と `--mount-root` の組み合わせごとに観測できる

**デメリット**
- フラグが増える（ただし “通常は何も指定しない” で済むように設計できる）
- ドキュメント量は増える

**向いているケース**
- 今回の要件（特に worktree）を最初から確実に満たしたい場合

## 推奨案（私のおすすめ）
**推奨: C（`--path` と `--mount-root` を分ける）**

### 推奨理由（具体）
- あなたの要件は「親を大きくマウント」と「初期ディレクトリは PWD/指定パス」が同時に必要です。これは 1つの `--path` では表現が崩れやすいです。
- “推定が外れて困る” のを最小化するには、**自動推定 + 明示指定の逃げ道** が必須です。
- `--path` を workdir と固定しておくと、UX・実装・テストの責務分割が明確になります。

## 仕様に落とすときの候補（例）
- `agent-sandbox up`（または `start`）
  - `--path <dir>`: workdir（省略時は PWD）
  - `--mount-root <dir>`: mount root（省略時は自動推定）
  - `--name <string>`: 明示コンテナ名（省略時は自動生成; Q-004）

例:
- `agent-sandbox up`（PWD を workdir、mount root は自動推定）
- `agent-sandbox up --path .`（明示的に同じ意味）
- `agent-sandbox up --path ./worktrees/feature-a --mount-root .`

## 実装メモ（この repo への落とし込み観点）
現状構造に当てはめると、最低でも以下の “2値” が必要です。

- `MOUNT_ROOT_HOST`（ホスト側）: `${SOURCE_PATH}` 相当
- `WORKDIR_HOST`（ホスト側）: PWD or `--path`

そこから `.env` に落とす値は：
- `SOURCE_PATH` = `MOUNT_ROOT_HOST`
- `CONTAINER_MOUNT_POINT`（新設候補） = `/srv/workspace` など（Q-005）
- `PRODUCT_WORK_DIR` = `CONTAINER_MOUNT_POINT` + `relpath(WORKDIR_HOST, MOUNT_ROOT_HOST)`

この計算が正しいかどうかは、テストで観測可能（例: `docker compose exec -w ... pwd` が期待通り）です。

## あなたが回答しやすいチェック（どれを優先したいか）
- 「通常は何も考えず `agent-sandbox up` で動いてほしい」→ C が有利
- 「運用は多少面倒でも、実装を単純にしたい」→ B もあり得る
- 「worktree 自動判定は怖いので、親は必ず指定したい」→ C で `--mount-root` 必須運用（または Q-002 で A）も可能

