# Q-005: コンテナ内のマウント先パスを固定にするか（`/srv/workspace` 等）

## この質問の意図
ホストのディレクトリをコンテナへ bind mount するとき、コンテナ内の “マウント先パス” をどうするかは、運用・互換性・実装難易度に直結します。

特にこの repo は現状：
- `/srv/${PRODUCT_NAME}` をワークスペースとして想定（`Dockerfile`, `docker-compose.yml`, `Makefile`）
- `PRODUCT_NAME` が build arg になっている（= コンテナイメージ構成に影響）

今回 “任意ディレクトリをマウントして起動” をやるなら、**毎回 image を build し直さずに** マウントできる設計が望ましいです。

## 選択肢

### A) コンテナ内マウント先を固定（例: `/srv/workspace`）
**定義**: どのインスタンスでも `MOUNT_ROOT_HOST → /srv/workspace` のように固定する。初期 workdir は `/srv/workspace/<relpath>` として計算する。

**メリット**
- image build に依存しない（`PRODUCT_NAME` を動的に変える必要が薄い）
- 仕様が単純でテストが書きやすい（常に同じ mount point）
- 複数コンテナでも構成が揃う（説明しやすい）

**デメリット**
- 既存の `/srv/${PRODUCT_NAME}` 前提のドキュメント/慣れとズレる
  - ただし、環境変数 `PRODUCT_WORK_DIR` を “実際の workdir” にしておけば、多くの箇所は互換を保てる

---

### B) コンテナ内マウント先を動的にする（例: `/srv/<generated>`）
**定義**: インスタンスごとに `/srv/<name>` をマウント先にし、`PRODUCT_WORK_DIR` もそれに合わせる。

**メリット**
- `docker ps` などで “中のパス” と “外のパス” の対応が直感的になる可能性
- 既存の `/srv/${PRODUCT_NAME}` 文化を延長しやすい

**デメリット**
- マウント先ディレクトリがコンテナ内に存在しない場合、Docker が root 権限で作ってしまい権限問題が出る可能性がある（特に Linux 環境）
- `Dockerfile` の `PRODUCT_NAME` build arg に依存すると、**インスタンスごとに build** する方向に寄りがち（重い）
- 実装の面倒が増える（entrypoint で mkdir/chown 等が必要になる可能性）

---

## 推奨案（私のおすすめ）
**推奨: A（コンテナ内マウント先は固定）**

### 推奨理由（具体）
- “任意ディレクトリから起動” を現実的にするには、起動が軽いことが重要です。マウント先を固定すれば、image ビルドや build arg 変更を避けやすいです。
- worktree 親マウント + workdir 分離の計算も固定 mount point の方がシンプルです。
- 既存互換は `PRODUCT_WORK_DIR` を “実際の初期 workdir” にしておくことで担保しやすいです（`Makefile` の `-w` など）。

## 仕様に落とすときの候補
- `CONTAINER_MOUNT_POINT=/srv/workspace`（新設 env）
- `SOURCE_PATH=<mount root host>`
- `PRODUCT_WORK_DIR=<container mount point + relative>`（初期 workdir）

例:
- mount root: `/Users/me/repos/myrepo` を `/srv/workspace` にマウント
- workdir: `/Users/me/repos/myrepo/worktrees/feature-a`
  - container workdir: `/srv/workspace/worktrees/feature-a`

## 互換性（既存運用との共存）
2系統を許す設計が取り得ます。
- 既存 `sandbox.config` ベース: `/srv/${PRODUCT_NAME}` をそのまま使う（従来通り）
- 新スクリプトベース: `/srv/workspace` 固定（推奨）

“最終的にどちらかへ統一” は後で検討しても良いですが、まずは要件を満たすために共存させるのが安全です。

## あなたが回答しやすい確認ポイント
- 既存の `/srv/${PRODUCT_NAME}` という UX を今後も強く残したいですか？
  - はい → B 寄りも検討（ただし実装重め）
  - いいえ/どちらでも → A が無難

