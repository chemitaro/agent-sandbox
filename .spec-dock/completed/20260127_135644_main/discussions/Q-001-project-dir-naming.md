# Q-001: `<project_dir>`（`/srv/mount/<project_dir>` の名前）を何で決めるか

## 決定（ユーザー回答）
- 決定: **A（`basename(abs_mount_root)` を原則そのまま使う）**
- 例外: unsafe な名前は **自動で安全名へ変換**（Q-002）

## このシートの目的
To-Be では、コンテナ内のマウント先（= プロジェクトルート）を `/srv/mount` 固定ではなく、`/srv/mount/<project_dir>` 配下にします。  
このとき **`<project_dir>` をどう決めるか**が、次の3点に直結します。

- 1) 人間にとって分かりやすいか（“プロジェクト名が見える”）
- 2) 安全に動くか（Docker Compose / bash / 各種CLI が壊れない）
- 3) Trust/ログの混線を防げるか（`mount` 固定問題の再発防止）

このシートは、Q-001（命名ルール）を “選べる状態” にするための材料です。

## 前提（As-IsとTo-Beの接点）
- As-Is:
  - `host/sandbox` が `PRODUCT_WORK_DIR=/srv/mount` を固定注入している（`host/sandbox:220`）
  - `docker-compose.yml` は `working_dir=${PRODUCT_WORK_DIR}` かつ `SOURCE_PATH:${PRODUCT_WORK_DIR}` で bind mount（`docker-compose.yml:13,23`）
  - そのため、典型ケースでコンテナ内ルートが常に `/srv/mount`（= `mount`）になる
- To-Be:
  - `PRODUCT_WORK_DIR=/srv/mount/<project_dir>` にする
  - `container_workdir=/srv/mount/<project_dir>/<rel>` にする

## “なぜ命名が重要か”（混線の本質）
この repo は `.agent-home/` をホストに永続化し、**複数コンテナ間で共有**します（`docker-compose.yml:27-35`）。  
つまり、プロジェクト識別がパス依存の場合、**パスが衝突すると “別プロジェクトが同一扱い”**になり得ます。

例（重要）:
- もし `<project_dir>` が単に `basename(abs_mount_root)` だけで決まると、
  - `/Users/me/work/foo` と `/tmp/foo` が **どちらも** `/srv/mount/foo` になり得る
  - その結果、Trust キーやログ/状態が衝突し、**信頼境界が意図せず共有**される可能性がある

この点は、今回の “mount 固定で混線” と同じ根っこ（= “コンテナ内の識別子が一意でない”）なので、Q-001 で確実に潰したいポイントです。

## 選択肢
### 選択肢A: `basename(abs_mount_root)` をそのまま `<project_dir>` にする（見た目最優先）
例:
- mount-root: `/Users/me/work/MyProject`
- `<project_dir>`: `MyProject`
- container mount: `/srv/mount/MyProject`

Pros:
- 直感的（ホストと同名で分かりやすい）
- 変換が少なく驚きがない

Cons:
- 同名ディレクトリが別場所にあると衝突し得る（Trust/ログ混線）
- 文字種によっては compose の volume 記法（`host:container`）を壊す可能性（特に `:`。詳細は Q-002）
- 長すぎる名前で扱いづらくなる可能性

### 選択肢B: `basename(abs_mount_root)` を slug 化して `<project_dir>` にする（安全優先）
例:
- `My Project` → `My-Project`（例）

Pros:
- “危ない文字” を排除しやすい（compose/bash/CLI に優しい）
- ある程度読みやすさを維持できる

Cons:
- 元の名前と完全一致しない（見た目が変わる）
- slug の結果が同じになる衝突が起き得る（例: `a b` と `a-b`）

### 選択肢C: `slug + hash` を `<project_dir>` にする（安全 + 一意性）
例:
- `<label>` = slug(basename) = `myproject`
- `<hash>` = hash12(abs_mount_root) = `1a2b3c4d5e6f`
- `<project_dir>` = `myproject-1a2b3c4d5e6f`

Pros:
- 衝突しにくい（別場所の同名プロジェクトでも分離できる）
- “見た目” と “一意性” のバランスが良い（prefix で人間にも判別可能）
- Trust/ログ混線を強く防げる（今回の課題に直撃）

Cons:
- ディレクトリ名が長くなる
- “完全に同名で見える” ことは諦める必要がある

## 私の分析（推奨案）
推奨: **選択肢C（slug + hash）**

理由:
- この repo は `.agent-home` を共有するため、「コンテナ内パスが一意であること」は運用上かなり重要です。
- 今回の問題（全部 `mount`）は “識別子が固定” で壊れているので、将来の類似事故を避けるには “一意性” を仕様として取り込むのが安全です。
- `slug + hash` は、ユーザー体験としても「同名だけど別プロジェクト」を識別でき、かつ壊れにくいです。

妥協案（見た目重視派向け）:
- 通常は A（basenameそのまま）を使い、**unsafe/衝突が疑われる場合のみ C にフォールバック**。
  - ただし「衝突検出」をどう定義するかが別途必要になり、設計が少し複雑になります。

## 決めたいこと（あなたに聞きたいこと）
Q-001（回答フォーマット）:
- どれを採用しますか？
  - A: basenameそのまま
  - B: slug
  - C: slug + hash（推奨）

追加で、もし “絶対にホスト名と同一に見せたい” 等のこだわりがあれば、その条件も教えてください（例: “hashは絶対付けたくない” など）。
