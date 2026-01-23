# Q-007: スクリプト/コマンドの提供形（どこからでも起動する方法）

## この質問の意図
要望は「どのディレクトリでも、エージェントが稼働するためのサンドボックスとして利用できるようにしたい」です。  
これは “機能” だけでなく “提供形（入口）” が UX を大きく左右します。

現状は repo root で `make start` が基本導線ですが、これは “この repo をカレントにする” 前提です。  
今回の拡張では、**別ディレクトリからでも起動できる入口** を提供するのが自然です。

## 選択肢

### A) repo内 `scripts/...` を直接叩く（最小）
例: `/<sandbox-root>/scripts/agent-sandbox up [--path ...]`

**メリット**
- 実装が最小。まず動かせる
- インストールが不要（ファイルがあるだけ）

**デメリット**
- “どこからでも” の UX は弱い（毎回フルパスが必要）
- PATH/alias をユーザーが整備しないと普段使いしにくい

---

### B) Makefile ターゲットで提供（`make start-here` 等）
例: repo root で `make start-here`（内部で PWD を拾う/引数を取る）

**メリット**
- 既存文化（make）に乗れる
- ドキュメントが書きやすい

**デメリット**
- “どこからでも” を満たすには `make -C <sandbox-root> ...` が必要になりがち
- 引数設計が Make の都合に引っ張られる

---

### C) `agent-sandbox` コマンド（ラッパー）として提供
例:
- `agent-sandbox up`（PWDを workdir として起動）
- `agent-sandbox up --path /path/to/repo`

実体は、この repo の `docker-compose.yml` を指して `docker-compose --env-file ...` を叩くスクリプト（bash等）。

**メリット**
- UX が最も良い（あなたの要望に直結）
- 将来的にサブコマンド（`up/shell/down/status/logs`）を整理しやすい

**デメリット**
- 配置/インストールの議論が必要
  - 例: repo内 `bin/agent-sandbox` を置き、ユーザーが PATH に通す/aliasを貼る、など

---

## 推奨案（私のおすすめ）
**推奨: まず C を repo内スクリプトとして実装し、導入は “PATHに通す/alias” をドキュメントで案内**

### 推奨理由
- あなたの要望「どのディレクトリでも」を最も素直に満たせます。
- “インストール” をいきなり仕組み化せずとも、まずは `bin/agent-sandbox` を用意すれば実現できます。
  - ユーザーは `ln -s <sandbox-root>/bin/agent-sandbox ~/bin/agent-sandbox` のように各自で導入できる
- 将来的に npm/brew などへ拡張する余地も残せます（今はスコープ外にできる）。

## 仕様に落とすときの候補（コマンド案）
- `agent-sandbox up [--path <dir>] [--mount-root <dir>] [--name <name>]`
- `agent-sandbox shell [--path <dir>] ...`（コンテナに attach）
- `agent-sandbox down [--name ...]`（対象インスタンスを停止/削除）
- `agent-sandbox ps` / `status` / `logs`

## 実装メモ（この repo の構造に合わせる）
“どこからでも” を実現するには、スクリプト自身が sandbox repo の場所を知る必要があります。

- スクリプトのパス（`$0`）から `SANDBOX_ROOT` を求める（`realpath`/`pwd -P` 等）
- `docker-compose -f "$SANDBOX_ROOT/docker-compose.yml" --env-file "$SANDBOX_ROOT/.env.instances/<id>.env" up -d` のように実行する

この方式なら、ユーザーがどこで実行しても確実に同じ compose ファイル・同じ `.agent-home` を参照できます。

## あなたが回答しやすい確認ポイント
- “導入” はどれが良いですか？
  - A: repo内に置くだけでOK（PATH/aliasは各自）
  - B: `make install` 的な補助も欲しい（ただしホスト環境依存）
  - C: npm/brew などで配布したい（今回は大きめ）

