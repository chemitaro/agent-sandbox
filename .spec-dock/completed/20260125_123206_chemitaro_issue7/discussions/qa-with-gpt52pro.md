## 1. 依頼の背景（ツール概要）

私は OSS の開発支援ツール（Docker ベース）を使って、コンテナ内で Codex CLI を動かし、リポジトリごとの `.codex/skills` を使って開発作業を進めています。

対象ツール（公開リポジトリ）:
- `agent-sandbox`（本件の sandbox CLI を含む）
- URL: https://github.com/chemitaro/agent-sandbox

このツールは概ね次の構成です:
- ホスト側の `sandbox` コマンドが Docker Compose を起動
- ホストのソースコード領域をコンテナ内の `/srv/mount` にマウント
- コンテナ内で `codex` を起動して作業
- `~/.codex/config.toml`（コンテナ側）はホスト側 `.agent-home/.codex/config.toml` をボリュームマウントして共有

---

## 2. 何が問題か（症状）

ローカル（ホスト）で Codex CLI を実行する場合は、対象プロジェクトの `.codex/skills` が正しく認識されます。  
しかし、上記の Docker コンテナ環境を介してコンテナ内で Codex CLI を使うと、**プロジェクト固有の skills が認識されない**ケースがあります。

具体的には、コンテナ内で `codex` を起動しても、以下のような状態になります:
- system skills は見えるが、repo-scope（プロジェクト内 `.codex/skills`）が見えない
- 結果として、プロジェクトに用意したワークフロー（SKILL.md）を利用できない

---

## 3. 再現条件（重要）

本件のキモは「コンテナ内の作業ディレクトリの形」です。

### パターンA: `/srv/mount` 自体が repo root（mount 直下がリポジトリ）
- 例: コンテナ側の作業ディレクトリ = `/srv/mount`
- この場合は skills が認識されやすい（少なくとも問題が起きにくい）

### パターンB: `/srv/mount/<repo>` が repo root（mount 直下が親で、repo がサブディレクトリ）
- 例: コンテナ側の作業ディレクトリ = `/srv/mount/taikyohiyou_project` のような形
- このパターンで **repo-scope skills が認識されない**ことがある

このツールは Git worktree を想定しており、「複数 worktree を包含できるように、worktree 群の LCA（最小共通祖先）を mount root にする」挙動を取り得ます。  
その結果、**mount root が repo root より上位**になり、コンテナ内では repo root が `/srv/mount/<repo>` になってしまうことがあります。

---

## 4. 既に分かっていること（観測事実）

次の挙動は高い確度で確認できています:

1) Codex の `projects.<path>.trust_level="trusted"` は、少なくともこのケースでは **親ディレクトリ trusted を子に継承していない**ように見えます。  
   - 例: `projects."/srv/mount" = trusted` だけでは、`/srv/mount/<repo>` の repo-scope skills が見えないケースがある

2) しかし `projects."/srv/mount/<repo>" = trusted` のように **repo root と一致するパス**を追加すると、repo-scope skills が認識される。  
   - つまり trust 判定が「prefix/祖先一致」ではなく「project root の完全一致（またはそれに近い）」である疑いがある

3) 「単一コンテナ内で複数 worktree を並行運用する」ことが必須要件です。  
   - worktree をコンテナ内でも作る
   - worktree 同士を比較してレビューする
   - 複数 worktree にまたがる作業を日常的に行う

このため「1コンテナ=1worktree」に割り切って `/srv/mount` を repo root に固定する案は、要件を満たしません（並行運用が難しい）。

---

## 5. 現在の暫定対応と、その問題点

暫定対応としては `~/.codex/config.toml` の `projects` に、コンテナ内の repo root パス（例: `/srv/mount/<repo>`）を `trusted` 登録すると skills が見えるようになります。

しかし、この方式は以下の理由で避けたいです:
- 外部ツール（シェルスクリプト等）が `config.toml` を機械編集するのは、Codex 側の仕様変更や config の構造変更で壊れやすい
- worktree を増やすほど `projects` が増殖し、設定ファイルが肥大化する
- 同じ repo でも mount のされ方でパスが微妙に変わると、実質的な重複エントリが増える可能性がある

---

## 6. あなたに依頼したいこと（最重要）

Codex CLI（OSS）の **ソースコードを参照して**、次の点を徹底的に調査してください。

### A) project root（プロジェクトルート）決定ロジック
- 何を marker として project root を決めているか（`.git` / `.codex` / その他）
- worktree のときの判定はどうなっているか
- symlink / `..` / realpath 正規化などはどの層で行っているか

### B) trust 判定ロジック（`projects`）
- `projects` のキー（path）に対するマッチング仕様:
  - 完全一致か？
  - 祖先（prefix）継承があるか？
  - ある場合、どのようなルールか？
- 「`/srv/mount` を trusted にしても `/srv/mount/<repo>` が trusted にならない」なら、それは仕様として意図されているのか（セキュリティ設計上の理由など）

### C) skills の探索・ロード条件
- repo-scope skills はどこからロードするのか（`$PROJECT_ROOT/.codex/skills` 等）
- trust が skills ロードにどう関与しているか（どの条件分岐で弾かれているか）

### D) ベストプラクティス（単一コンテナ内で複数 worktree 並行、が必須）
この要件を満たしつつ、次を同時に達成する設計/運用案を提案してください:
- `projects` が増殖しない/増殖しづらい
- `config.toml` を外部ツールが脆く書換しない（Codex の公式機能・公式設定レイヤーに寄せる）
- 仕様変更耐性が高い
- セキュリティ（最小権限）も破綻しない

ヒント（方向性の例。これらに縛られず検討してください）:
- 公式の設定レイヤー（例: `/etc/codex/config.toml` のような “配布/環境レイヤー”）があるなら、そこで trust を配る設計
- `-c`（config override）や profile 等の **公式CLI引数**で “起動時だけ trust を付与” できるか
- trust を wildcard/prefix でまとめられる公式仕様があるか（無いなら、なぜ無いのかも含めて）
- マウント設計を “二重マウント” などにして、「Codex が見る project root」と「worktree 全体参照」を矛盾なく両立できるか

---

## 7. 望むゴール（理想状態）

- コンテナ内で複数 worktree を並行に扱える（作成/編集/比較/レビューができる）
- どの worktree でも `.codex/skills` が安定して認識される
- trust 設定が増殖しない（または増殖しても管理しやすい/壊れにくい）
- “外部スクリプトが機械的に config を編集する” を避け、Codex の公式機構に寄せた解決になっている


---


以下は、**Codex CLI（openai/codex・Rust 実装）の挙動を、取得できた OSS ソース（主に `codex-rs/core/src/config_loader/mod.rs`）と、skills 実装をコード参照付きで追っている解析記事**を根拠に、A〜D を順に整理した調査結果です。
（GitHub の “blob” 表示がこちらの環境では正常に展開できず、**raw の先頭断片**と、コード行リンクを含む公開解析記事を併用しています。根拠はすべて引用可能な URL ソースに紐付けています。）

---

# 結論（あなたの観測と一致する「原因」）

あなたが観測している

* `projects."/srv/mount" = trusted` **だけでは** `/srv/mount/<repo>` の repo-scope skills が見えない
* `projects."/srv/mount/<repo>" = trusted` を足すと見える

は、Codex 側の trust 判定が **「祖先 prefix での継承」ではなく、（少なくとも）特定キーへの“完全一致”に近い lookup** で動いているためです。
実際、`ProjectTrustContext::decision_for_dir()` の lookup は（少なくとも）次の順で **Map のキー一致**を見に行っており、**`/srv/mount` のような任意の親ディレクトリ prefix は探索しません**。 ([GitHub][1])

1. 対象 dir 自身（`dir_key`）
2. `project_root_key`
3. （あれば）`repo_root_key`

そのため、Pattern B で Codex が `project_root_key` を `/srv/mount/<repo>` 側に決めてしまうと、`projects."/srv/mount"` を trusted にしても lookup に引っかからず、結果として **Project レイヤ（`.codex/config.toml`）が untrusted 扱いで無効化 → `.codex/skills` が探索対象に入らない**、という流れになります。 ([GitHub][1])

---

# A) project root 決定ロジック（markers / worktree / 正規化）

## A-1. markers（何を project root の目印にするか）

Codex には `project_root_markers` という設定があり、**「Project レイヤより前に読み込まれた config の結果」**から決まります。
（＝ repo の `.codex/config.toml` で後から変える用途ではなく、**ユーザー/システム/ランタイム上書き側で決める前提**です。） ([GitHub][1])

また、デフォルトの markers は `.git` です。 ([GitHub][1])
さらに、`project_root_markers` を **空配列にすると root detection を無効化**する、という仕様コメントがコード上にあります。 ([GitHub][1])

> ここから論理的に言えること
> Pattern B（`/srv/mount/<repo>` が repo root）で `.git` が各 worktree 直下に存在する限り、project root は多くの場合 `/srv/mount/<repo>` に寄ります。
> その結果、`projects."/srv/mount"` を trusted にしても `project_root_key` と一致しないので trust が効かない、という筋になります。 ([GitHub][1])

## A-2. worktree の扱い（“worktree root” と “repo root”）

Codex は repo-scope の config を読む際に、コメント上 **`git rev-parse --show-toplevel` を repo root として採用**しています。 ([GitHub][1])
Git worktree の場合、この `--show-toplevel` は「その worktree のルート」を返すので、repo-scope config（`<worktree>/.codex/config.toml`）は worktree ごとに解決されます（期待どおり）。

一方で trust 文脈には `resolve_root_git_project_for_trust` という別名の root 解決があり、`config` 側で import されています。 ([fossies.org][2])
さらに、**「primary repository working directory が trusted なら worktrees が trust を継承できる」**という趣旨のコメント断片が公開差分/閲覧サイト側の抜粋に出ています。 ([fossies.org][3])

> 含意
>
> * Codex は「worktree 群を 1 つの“信頼単位”にまとめる」方向性自体は持っています。
> * ただし、それは一般の親ディレクトリ prefix 継承ではなく、“primary repo” という概念に紐付いた継承である可能性が高いです。 ([fossies.org][3])

## A-3. symlink / `..` / realpath 正規化

取得できた断片では、trust lookup のキーは `AbsolutePathBuf` を `to_string_lossy()` した文字列で扱っています。 ([GitHub][1])
ただし **「どの段階で canonicalize（realpath 化）しているか」**は、今回こちらの環境制約（GitHub blob のコード本体が展開できない）により、当該箇所の一次ソースを提示できません。
実務上は、**“設定に書いた path” と “Codex が内部で作った AbsolutePathBuf” が同一表現になっていること**が重要で、symlink を挟む場合は特に一致ズレが起きやすい点に注意が必要です。 ([GitHub][1])

---

# B) trust 判定ロジック（`projects` のマッチ仕様）

## B-1. マッチングは prefix 継承ではない（少なくともここでは）

`ProjectTrustContext::decision_for_dir()` は、`projects_trust: HashMap<String, TrustLevel>` を参照し、以下の **キーの “完全一致”**で trust_level を探します。 ([GitHub][1])

* `dir_key`（その dir 自身の絶対パス文字列）
* `project_root_key`
* `repo_root_key`（存在すれば）

そして、いずれにもヒットしないと `trust_level: None` を返します。 ([GitHub][1])

この実装から言えるのは、

* `projects."/srv/mount"` を trusted にしても、**`project_root_key` が `/srv/mount/<repo>` ならヒットしない**
* したがって、あなたが観測した “親 trusted が子に継承されない” は **仕様どおりに起きうる**

ということです。 ([GitHub][1])

## B-2. なぜ prefix 継承をしないのか（セキュリティ設計としての合理性）

これはコード断片から直接 “意図” を断言できませんが、セキュリティ設計としては合理的です。

* 親ディレクトリを trusted にしただけで、そこに新しく作られた任意の子ディレクトリ（攻撃者が置いた repo など）が自動で trusted になると、**trust の爆発半径が大きく**なる
* そのため「明確な単位（project root / repo root）に対して trust を付与」し、**境界を保つ**設計になりがち

実際、Unix の system config として `/etc/codex/config.toml` を読み、`/etc/codex/` 配下（skills/ や rules/）も “config folder” として扱う、というセキュリティ文脈を意識したコメントが存在します。 ([GitHub][4])

---

# C) skills の探索・ロード条件（repo-scope skills が消える分岐）

## C-1. “どこから skills をロードするか”

skills の検索ルートは「設定レイヤースタック（config layer stack）に基づいて決める」実装です。 ([Zenn][5])
そのため、repo-scope の skills は概ね

* repo（または project）レイヤの **config フォルダ**
* その配下の `skills/`（＝ `.codex/skills`）

が layer stack に入った場合に探索対象になります（あなたの理解どおりの “repo-scope skills”）。 ([Zenn][5])

また、skills 自体は起動時に SKILL.md を走査して **YAML フロントマター（名前・説明）だけ先に集め**、セッション開始時に一覧として system prompt に注入する、という段階構造で説明されています（コード行リンク付き）。 ([Zenn][5])

## C-2. trust が skills ロードにどう関与しているか

ここが今回の核心です。

Codex は config ロード順として、コメント上、少なくとも次を行います。 ([GitHub][1])

* tree 親を辿って `./.codex/config.toml` を探す（ただし **untrusted なら “loaded but disabled”**）
* repo root の `$(git rev-parse --show-toplevel)/.codex/config.toml` を読む（同じく **untrusted なら “loaded but disabled”**）

つまり、

1. Pattern B で trust が `/srv/mount/<repo>` に乗らない
2. → repo の `.codex/config.toml` レイヤが **disabled 扱い**になる
3. → layer stack から repo の `.codex` フォルダが落ちる
4. → `.codex/skills` が探索ルートから外れる
5. → system skills だけ見える

という因果が、コードコメントとあなたの観測に整合します。 ([GitHub][1])

---

# D) ベストプラクティス提案（複数 worktree 並行、trust 増殖を抑え、公式機構に寄せる）

ここからは「単一コンテナで複数 worktree を並行運用」という必須要件を守ったまま、増殖・脆さを避ける運用設計です。
結論から言うと、**“Codex が見る project root” を mount root と一致させる**のが最も筋が良いです（prefix 継承が無い以上、ここを一致させるのが唯一の構造的解決）。

---

## 提案 1（推奨）: `/etc/codex/config.toml` + `project_root_markers` で “workspace root” を固定する

### ねらい

* `projects` を **1 エントリ（`/srv/mount`）**に固定
* worktree が増えても `config.toml` を増殖させない
* 外部スクリプトで `~/.codex/config.toml` を機械編集しない（＝**システムレイヤに閉じ込める**）
* trust 境界を `/srv/mount` に限定（最小権限の範囲を保つ）

### 仕組み（コード上の根拠）

* `project_root_markers` は Project レイヤ前に読み取られ、root detection に使われる（空配列で無効化も可能） ([GitHub][1])
* trust lookup は `project_root_key` と一致するキーを見に行く（prefix ではない） ([GitHub][1])
* `/etc/codex/config.toml` が Unix のデフォルト設定読み込みパスとして扱われ、`/etc/codex/` は config folder（skills/ rules/ も有効） ([GitHub][4])

### 実装案（コンテナ内に配布する system config）

`/etc/codex/config.toml` を用意（イメージに同梱 or docker-compose で read-only マウント）:

```toml
# /etc/codex/config.toml

# 1) project root を “workspace root” にしたいので、
#    デフォルト(.git)ではなく専用マーカーに切り替える
project_root_markers = [".codex-workspace-root"]

# 2) workspace root だけを trusted にする（projects が増殖しない）
[projects."/srv/mount"]
trust_level = "trusted"
```

そして `/srv/mount` 直下にマーカーファイル（or ディレクトリ）を作る:

```bash
touch /srv/mount/.codex-workspace-root
```

> これで起きること（期待挙動）
>
> * どの worktree（`/srv/mount/<repo>`）から Codex を起動しても、project root は `/srv/mount` として解決されやすくなる（.git ではなく marker が基準になるため） ([GitHub][1])
> * trust lookup が `project_root_key="/srv/mount"` に一致し、repo `.codex/config.toml` が disabled にならず layer stack に乗る ([GitHub][1])
> * 結果として `.codex/skills` が探索対象になり、repo-scope skills が安定して見える ([GitHub][1])

### トレードオフ（重要）

* `/srv/mount` 配下はすべて「同一プロジェクト」として trust が効きやすくなるため、**`/srv/mount` を “信頼してよい作業領域だけ” に限定**するのが前提です。
* `project_root_markers` を変更することで、Codex が project root 由来の探索（例: project doc など）をどこで打ち切るかの挙動が変わる可能性があります（ただし repo の `.codex/config.toml` は `git rev-parse --show-toplevel` で別途読む設計なので、repo 固有設定が失われる方向には働きにくいです）。 ([GitHub][1])

---

## 提案 2: “worktree trust 継承（main project → worktrees）” を活用して **1 repo = 1 trust** に寄せる

あなたの運用が「同一 repo の worktree 群」を主に扱うなら、Codex 側には **main project を trusted にすると worktrees が trust を継承できる**方向性が示唆されています。 ([fossies.org][3])

この場合の狙いは、

* worktree を増やしても `projects` を増やさず、**main の 1 エントリだけ**で済ませる

です。

ただし、これは **“primary repository working directory” が何として解決されるか**に依存します。
もしあなたが「bare repo + worktrees」型のレイアウトを使っていて primary working directory が存在しない（もしくは Codex が解決できない）場合、この継承が効かず、あなたの観測どおり “worktree ごとに trust が必要” になっている可能性があります（この点は一次コードで断言できないため推測扱い）。 ([fossies.org][3])

---

## 提案 3: `--config`（ランタイム上書き）で “起動時だけ trust” を与える（ファイル編集を避ける）

config loader のコメント上、最上位レイヤに **runtime（例: `--config` flags）**が存在します。 ([GitHub][1])
そのため、「外部ツールが config.toml を書き換える」のではなく、

* agent-sandbox が **`codex` 起動引数として**必要な trust を注入する

という設計に寄せられます。

### 特徴

* 永続ファイルは増殖しない（セッションごと）
* Codex の “公式のレイヤ” を使うので、機械編集より壊れにくい
* ただし「worktree ごとに 1 回は引数で path を与える」必要が残る（根本解決ではなく運用最適化）

---

## 提案 4: host と container で `~/.codex` を共有しない（CODEX_HOME を分ける）

あなたの構成だと、host と container で

* trust の path 文字列が完全に別物（host: `/Users/...`、container: `/srv/mount/...`）

になるため、同一 `config.toml` を共有すると `[projects]` が肥大化しやすく、ズレの温床になります。

Codex には `CODEX_HOME` がある（環境変数があればそれを使い、なければ `~/.codex` を使う）旨のコード断片が公開されています。 ([Qiita][6])

したがって、

* host: `~/.codex`（従来どおり）
* container: `CODEX_HOME=/agent-home/.codex-container` のように分離

として **環境ごとに trust を 1 エントリに抑える**のは、構造的にかなり強いです（あなたの「増殖しづらい・壊れにくい」に直結）。

---

# まとめ（あなたの要件へのマッピング）

あなたの必須要件（単一コンテナ・複数 worktree 並行）を守りつつ、最も「増殖しづらい / 公式レイヤ寄せ / 変更耐性 / セキュリティ境界も維持」を満たすのは、

* **提案 1:** `/etc/codex/config.toml`（system layer）で `project_root_markers` を workspace root に向け、`projects."/srv/mount"` の 1 エントリだけで trust を成立させる

です。 ([GitHub][4])

worktree trust 継承（提案 2）は “同一 repo worktree 群” に寄せられる場合に追加で効く可能性がありますが、あなたの観測（pattern B で頻発）からは、**まず提案 1 の「project root を mount root に一致させる」**が最短で安定します。 ([GitHub][1])

[1]: https://raw.githubusercontent.com/openai/codex/main/codex-rs/core/src/config_loader/mod.rs "https://raw.githubusercontent.com/openai/codex/main/codex-rs/core/src/config_loader/mod.rs"
[2]: https://fossies.org/linux/codex-rust/codex-rs/core/src/config/mod.rs?utm_source=chatgpt.com "Codex CLI: codex-rs/core/src/config/mod.rs"
[3]: https://fossies.org/linux/codex-rust/codex-rs/core/src/config/mod.rs "https://fossies.org/linux/codex-rust/codex-rs/core/src/config/mod.rs"
[4]: https://raw.githubusercontent.com/openai/codex/main/codex-rs/core/src/config_loader/mod.rs?utm_source=chatgpt.com "https://raw.githubusercontent.com/openai/codex/mai..."
[5]: https://zenn.dev/takiko/articles/codex-cli-agent-skills-implementation "https://zenn.dev/takiko/articles/codex-cli-agent-skills-implementation"
[6]: https://qiita.com/nogataka/items/c673389a80901f83909d "https://qiita.com/nogataka/items/c673389a80901f83909d"


---

以下は **Codex CLI（openai/codex）側の実装（主に Rust の `codex-rs/core/src/config_loader/mod.rs`）に基づいて**、ご提示の症状がなぜ起きるか／どこで弾かれているか／どう直すのが “公式機構寄せ” で堅いか、を整理したものです。

（結論から言うと、あなたの観測「`projects."/srv/mount"` trusted が `/srv/mount/<repo>` に継承されない」は **ほぼその通り**で、**prefix/祖先継承は実装されていません**。ただし、**`project_root` を `/srv/mount` にする**と、`projects."/srv/mount"` trusted が **“project root として” 作用して、結果的に全 worktree で `.codex/skills` が安定します**。）

---

## 0. 結論（最短の修正方針）

あなたの「パターンB（`/srv/mount/<repo>` が repo root）」で skills が見えない主因は、Codex が **プロジェクトの “project root” を `/srv/mount/<repo>` と判定する**ため、trust 判定が **`projects` のキーと “完全一致” しない**ことです。([GitHub][1])

したがって、`projects` を worktree ごとに増やさずに安定させるには、次が最も堅いです：

* **コンテナ環境専用の system config（`/etc/codex/config.toml`）で**

  * `project_root_markers` を **“mount root を project root にする marker”** に切り替える
  * `projects."/srv/mount".trust_level="trusted"` を 1 個だけ置く
* `/srv/mount` にその marker ファイルを置く（または起動時に `touch`）

これで、Codex の trust 判定が **`project_root_key="/srv/mount"` を参照するようになり**、各 worktree 配下の `.codex` フォルダ（= skills を含む “project config folder”）が **一括で有効化**されます。([GitHub][1])

---

## A) project root（プロジェクトルート）決定ロジック

### A-1. 既定 marker と探索方法

Codex の project root は `find_project_root()` で決めています。ロジックは非常に単純で、

* **`cwd` から親へ向かって `ancestors()` を辿る**
* 各 ancestor で `project_root_markers` に列挙された marker（パス要素）を `ancestor.join(marker)` して `metadata()` が取れたら、その ancestor を project root とする
* どれも見つからなければ `cwd` を project root とする

という挙動です。([GitHub][1])

既定 marker は `[".git"]` です。([GitHub][1])

### A-2. worktree での挙動

Git worktree の場合でも、多くのケースで worktree ルートには `.git` が **ディレクトリではなくファイル**として存在しますが、Codex の root 判定は `metadata()` の成否しか見ていないため、**`.git` がファイルでも marker として成立**します（= worktree ルートが project root になりやすい）。([GitHub][1])

これが、あなたのパターンBで「`/srv/mount/<repo>` が repo root として project root 扱いになる」大きな理由です。

### A-3. `project_root_markers` の設定レイヤ

`project_root_markers` は、**project layer 以外（system/user/CLI など）をマージした結果**から読み取られます。空配列 `[]` を指定すると root 検出を無効化して `cwd` が project root になります。([GitHub][1])

この設計はセキュリティ上重要で、**未 trust の repo が勝手に marker を変えて trust 境界をごまかす**ことを防ぎます（project layer そのものが trust により無効化され得るため）。([GitHub][1])

### A-4. symlink / `..` / realpath 正規化について

少なくとも `find_project_root()` 自体は `canonicalize()` を呼んでおらず、**渡された `cwd` の `ancestors()` をそのまま使う**実装です。([GitHub][1])
ただし `AbsolutePathBuf` 型が内部でどこまで正規化しているか（symlink 解決までやるか）は、この回答で参照できた範囲だけでは断言できません。実務上は、**trust キーの文字列一致に依存する**ので、symlink 経由のパス揺れや `..` を含む起動は避け、**Codex が実際に動作している絶対パス**（例: `/srv/mount/...`）で揃えるのが安全です。([GitHub][1])

---

## B) trust 判定ロジック（`projects`）

### B-1. trust 情報の取り込み

`projects` は `ConfigToml.projects` から読み取られ、各 project の `trust_level` があるものだけを `HashMap<String, TrustLevel>` に落としています。([GitHub][1])

つまり **`projects` のキーは “文字列” で、そのまま比較**されます（ここに wildcard/prefix 機構はありません）。([GitHub][1])

### B-2. マッチング仕様（完全一致 + “2 つのフォールバックキー”）

trust 判定の核は `ProjectTrustContext::decision_for_dir()` です。順序は次の通り：

1. **今評価している dir そのもののキー**（`dir_key`）が `projects_trust` に完全一致すれば、それを採用
2. なければ、**project root のキー**（`project_root_key`）が完全一致すれば、それを採用
3. なければ、**repo root のキー**（`repo_root_key`：`resolve_root_git_project_for_trust()` 由来）で完全一致すれば、それを採用
4. どれもなければ `trust_level=None`（未指定）

という実装です。([GitHub][1])

ここで重要なのは：

* **祖先 prefix を辿って “最も近い trusted” を探すような処理は無い**
* あるのは **(2) project root と (3) repo root のみ**（どちらも “単一キー”）

という点です。([GitHub][1])

### B-3. 「`/srv/mount` trusted でも `/srv/mount/<repo>` が trusted にならない」理由

パターンBでは `project_root_key` が `/srv/mount/<repo>` になりやすいので、trust 判定は

* `dir_key`（例: `/srv/mount/<repo>`）→ 未登録
* `project_root_key`（同じく `/srv/mount/<repo>`）→ 未登録
* `repo_root_key`（後述）→ 未登録 or 期待と違う

となり、`/srv/mount` のエントリは **参照されません**。
これがあなたの観測 (1)(2) と整合します。([GitHub][1])

### B-4. 仕様として意図されているか（セキュリティ理由）

コード上、project layer が untrusted の場合に `disabled_reason_for_dir()` が返す文言が「trusted にして project config folders を有効化せよ」という趣旨になっています。([GitHub][1])

つまり、**repo 内に置ける `.codex` フォルダ（skills/rules/config）を“暗黙に読み込む”こと自体が攻撃面になる**ので、Codex は「明示的に trust した project にだけ project config folder を許可する」方向に寄せています。([GitHub][1])

この観点からすると、`/srv` や `/tmp` のような親を trusted にしただけで、その配下に落ちてきた未知の repo の `.codex/skills` が勝手に有効になるのは危険で、**継承を敢えて入れないのは合理的**です。

---

## C) skills の探索・ロード条件と trust の関与

### C-1. skills は “config folder のサブフォルダ” として扱われる

`/etc/codex/config.toml` をロードする箇所に、**`/etc/codex/` は “config folder” として扱われ、`skills/` や `rules/` のようなサブフォルダも尊重される**と明記されています。([GitHub][1])

同様に、project layer は `.codex` ディレクトリが存在するディレクトリごとに積まれます（`load_project_layers()`）。([GitHub][1])
そして、その `.codex` ディレクトリ配下に “subfolders that are significant” があり得るので、`config.toml` が無くても空 entry を積む、という挙動になっています。([GitHub][1])

この設計から、repo-scope skills（あなたの `.codex/skills`）は：

* **`<layer_dir>/.codex/skills/...`** のような形で “project config folder のサブフォルダ” として取り扱われ、
* layer が **disabled（untrusted）** だと、skills も含めてその config folder の機能が落ちる

と解釈するのが自然です。([GitHub][1])

### C-2. trust が skills ロードにどう関与しているか

project layer は `project_layer_entry()` で、

* trusted → `ConfigLayerEntry::new(...)`
* untrusted/未指定 → `ConfigLayerEntry::new_disabled(..., reason)`

に分岐して積まれます。([GitHub][1])

そして disabled 理由が「trusted にして project config folders を有効化せよ」という趣旨です。([GitHub][1])
したがって、repo-scope skills が “見えない” のは、

* `.codex` 層が disabled になっている
* skills root が layer stack から外される（または読み取りが抑止される）

という経路が濃厚です。

また、外部のコードリーディング記事でも「skills の探索ルートが config layer stack から生成される」旨が説明されています。([Zenn][2])
（一次情報としては上の config_loader の設計がかなり強い根拠になります。）

---

## D) 必須要件（単一コンテナ内で複数 worktree 並行）を満たす “壊れにくい” 運用設計案

ここが最重要なので、**公式レイヤ／公式設定キーを最大限利用**する方向で、現実的な案を優先度順に出します。

---

### 推奨案: `project_root_markers` で “project root を `/srv/mount` に固定” して trust を 1 点に集約

あなたの現象は「trust の継承が無い」ではなく、より正確には

> “trust は project root（または repo root）にだけフォールバックする。
> だから project root を mount root にできれば、mount root trust が効く。”

です。([GitHub][1])

#### 仕組み（コード上の整合）

* `decision_for_dir()` は、dir 自身に trust が無いと **`project_root_key`** を見ます。([GitHub][1])
* つまり、**project root を `/srv/mount` にできれば**、`projects."/srv/mount".trust_level="trusted"` が **配下の `.codex` 層すべてに効く**（dir_key が未指定なら project_root_key を採用するため）。([GitHub][1])
* その状態で `load_project_layers()` は cwd→project_root の祖先列を走査し、各 worktree 直下の `<repo>/.codex` を拾える。([GitHub][1])
  ⇒ `.codex/skills` も（trust されている限り）拾える。

#### 実装（コンテナの system layer に閉じるのが堅い）

コンテナイメージ側（または Compose）で **`/etc/codex/config.toml`** を用意します。
（`/etc/codex/config.toml` が system config としてロードされるのはコードに明記されています。([GitHub][1])）

例（コンテナ内）:

```toml
# /etc/codex/config.toml

# mount root を project root として認識させるための marker
# ※ .git を入れると repo root で止まるので “入れない” のがポイント
project_root_markers = [".agent-sandbox-root"]

[projects."/srv/mount"]
trust_level = "trusted"
```

そして `/srv/mount/.agent-sandbox-root` を **起動時に作る**（空ファイルで十分）：

* entrypoint / init スクリプトで `touch /srv/mount/.agent-sandbox-root`
* あるいは host 側 sandbox CLI が LCA に `touch` してから compose up

これで `/srv/mount/<repo>` で起動しても project root が `/srv/mount` になり、`projects."/srv/mount"` の trust が効き、repo-scope skills が安定して見えるはずです。([GitHub][1])

#### トレードオフ（正直に）

* **セキュリティ境界が広がる**：`/srv/mount` 配下にある全ての `.codex` が trust 対象になります。
  → 逆に言えば、`/srv/mount` を “worktree 群専用ディレクトリ” に限定すれば、最小権限の原則とも両立できます。
* もし `/srv/mount` 配下に “信頼しない repo” が混ざり得るなら、次のように **明示的に untrusted を上書き**できます（`dir_key` が優先なので上書きが効く）。([GitHub][1])

```toml
[projects."/srv/mount"]
trust_level = "trusted"

[projects."/srv/mount/some-untrusted-repo"]
trust_level = "untrusted"
```

---

### 代替案1: `repo_root_key` を利用して “同一 git プロジェクト” の trust を 1 点に寄せる

`decision_for_dir()` には `repo_root_key` という第三のフォールバックが入っています。([GitHub][1])
これは設計意図として、**git 的に同一プロジェクトと見なせるもの（worktree を含む）を 1 点 trust で束ねたい**方向の可能性があります（関数名も `resolve_root_git_project_for_trust` で、その意図を示唆します）。([GitHub][1])

もしこれがあなたの環境で期待通りに働くなら、

* ある “代表 worktree”（あるいは “root git project”）のパスだけを `trusted`
* 他の worktree は `repo_root_key` が同じなので自動的に trusted 扱い

になり、`projects` の増殖が抑えられます。

ただし、あなたの観測ではこの恩恵が出ていない可能性が高い（= `repo_root_key` が worktree ごとに違う／または解決できず None になっている）ので、**確実性は推奨案より落ちます**。
（ここは Codex 側の `repo_root_key` が何を返しているかで決まります。trust 促し文言の trust_key がそれです。([GitHub][1])）

---

### 代替案2: 公式の “runtime overrides（`--config` flags）” で起動時にだけ trust を付与する

config_loader のコメントに「runtime e.g., **`--config` flags**」と明記があります。([GitHub][1])
つまり Codex CLI は、**起動引数で config を上書きする公式経路**を持っています。

この方式の利点は：

* `~/.codex/config.toml`（共有ファイル）を **機械編集しない**
* trust を “セッション単位” にできる（永続化しない）

ことです。

欠点は：

* sandbox CLI が起動時に worktree 群を列挙して `--config` を組み立てる必要がある（ただしこれは **“設定ファイルの構造を書き換える”より仕様変更耐性は高い**）
* worktree が多すぎると引数が長くなる可能性

です。

ただし、あなたの要件（単一コンテナ内で複数 worktree を常時並行）では、**起動時に `/srv/mount` 配下の “`.codex` を持つ dir” を列挙して trust を注入**すれば、実運用上は十分現実的です。

---

### 将来的な改善（上流提案として妥当な方向）

あなたの観測は、多くの人が同じところで困る類のものです。

とはいえ、単純な「prefix 継承をデフォルトで入れる」は危険なので、上流に出すなら例えば：

* `projects_inherit = true` のような **明示 opt-in**
* あるいは `projects_glob`（wildmatch）で **`/srv/mount/*` を trusted** にできるが、これも opt-in

のような “安全設計を崩さない形” が必要になります。

現時点のコードは「project config folders（skills/rules）を trust で明確に切る」設計なので、無条件継承を入れるのは設計思想と衝突しやすい、という見立てになります。([GitHub][1])

---

## まとめ（あなたの要求に対する最適解）

* **A / B はコード上ほぼ確定**です：

  * project root は marker（既定 `.git`）の **存在チェックで決まる**。([GitHub][1])
  * trust は `projects` のキーとの **完全一致**のみ（dir / project_root / repo_root の 3 キー）。祖先 prefix 継承は無い。([GitHub][1])
* **C（skills）は config folder のサブフォルダとして扱われ、project layer が untrusted だと無効化される**設計です。([GitHub][1])
* **D（要件達成）**は、公式設定レイヤに寄せるなら：

  1. **`/etc/codex/config.toml` で `project_root_markers` を mount root marker に変更**
  2. `projects."/srv/mount" = trusted` を 1 件だけ置く
  3. mount root に marker ファイルを置く
     が、最も “壊れにくく、増殖せず、運用が単純” です。([GitHub][1])

この方針なら、「1コンテナ=1worktree」に割り切らずに、**単一コンテナ内で複数 worktree を並行運用しつつ、どの worktree でも `.codex/skills` を安定認識**できます。

[1]: https://raw.githubusercontent.com/openai/codex/main/codex-rs/core/src/config_loader/mod.rs "https://raw.githubusercontent.com/openai/codex/main/codex-rs/core/src/config_loader/mod.rs"
[2]: https://zenn.dev/takiko/articles/codex-cli-agent-skills-implementation "https://zenn.dev/takiko/articles/codex-cli-agent-skills-implementation"


---

以下、**Codex CLI（OSS）の実装（Rust 側）を根拠に**、ご依頼の A〜D を順に整理します。結論から言うと、観測されている挙動は **「project root の決定」と「trust の照合が prefix 継承ではなく “限定的なキー一致”」**でほぼ説明できます。さらに、要件（単一コンテナ内で複数 worktree 並行）を満たしつつ `projects` 増殖を避けるには、**project_root_markers をコンテナ環境専用に再定義して “trust の基準となる project root を /srv/mount に寄せる”**のが最も堅いです。

---

# A) project root 決定ロジック

## 1) Codex の「設定レイヤ（config layer）スタック」は project root を前提に組み立てられる

`codex-rs/core/src/config_loader/mod.rs` のコメントに、レイヤが明確に書かれています。重要なのは、**`cwd` や “親ディレクトリを辿る .codex/config.toml” や “repo root の .codex/config.toml” は「読み込むが untrusted だと disabled」**という点です。 ([GitHub][1])

> * system `/etc/codex/config.toml`
> * user `${CODEX_HOME}/config.toml`
> * cwd `${PWD}/config.toml`（untrusted なら disabled）
> * tree parent directories を辿って `./.codex/config.toml`（untrusted なら disabled）
> * repo `$(git rev-parse --show-toplevel)/.codex/config.toml`（untrusted なら disabled）
> * runtime（`--config` flags 等）
>   （要旨） ([GitHub][1])

ここから分かること：

* **project root は “どこまで親を辿るか” の境界**になり得る（少なくとも trust context の基準になる）。
* repo root は別枠で **`git rev-parse --show-toplevel` 相当**で決めている（コメントに明記）。([GitHub][1])

## 2) project root marker はデフォルト `.git`、ただしユーザー/システムレイヤで上書き可能

同ファイルで、デフォルト marker は `.git` であることが定義されています。([GitHub][1])

```rust
const DEFAULT_PROJECT_ROOT_MARKERS: &[&str] = &[".git"];
```

さらに `project_root_markers` は **project レイヤより前（system/user + runtime overrides をマージした結果）から読む**実装になっています。([GitHub][1])
つまり、

* repo 内 `.codex/config.toml` に `project_root_markers` を書いても **root 決定には間に合わない**（その前に root を決めて trust context を作っている）。
* 反対に、**/etc/codex/config.toml（system レイヤ）や $CODEX_HOME/config.toml（user レイヤ）で container 専用の markers を指定できる**。

また、空配列を指定すると「root detection を無効化」する扱いであることもコメント/実装にあります（空配列を許容）。([GitHub][1])

## 3) worktree の判定は、少なくとも marker 的には “worktree root の `.git`” にヒットし得る

Git worktree では `.git` が **ディレクトリではなく “ファイル”**になるケースが普通ですが、marker は文字列指定なので、実装が「存在確認」なら worktree root でも普通にヒットします（＝project root が worktree root になりやすい）。
この前提が、あなたの観測（`/srv/mount/<repo>` を trusted にすると直る）と整合します。([GitHub][1])

## 4) 正規化（symlink / `..` / realpath）

trust 照合に使っているキー生成は少なくとも **`AbsolutePathBuf` → `.as_path().to_string_lossy()`**の文字列化です。([GitHub][1])
`AbsolutePathBuf` がどこまで canonicalize（symlink 解決）するかはこの断片だけでは断定できませんが、**「最終的に文字列一致」**なので、

* trust に登録するパスは **Codex が内部で採用する “見えている絶対パス表現” と同一**である必要があります（例：`/srv/mount` と `/srv/mount/` の差、symlink 経由、bind mount の経路違いなど）。([GitHub][1])

---

# B) trust 判定ロジック（`projects` のマッチング仕様）

あなたの観測 1)〜2) は、**実装上ほぼ “仕様” です**。

## 1) 祖先（prefix）継承は “ない”

`ProjectTrustContext::decision_for_dir()` が本丸で、やっていることは以下です（要約）：

1. **対象 dir そのもの**（dir_key）が `projects_trust` にあればそれを採用（完全一致）
2. そうでなければ **project_root_key** が `projects_trust` にあればそれを採用（完全一致）
3. そうでなければ **repo_root_key** が `projects_trust` にあればそれを採用（完全一致）
4. それ以外は untrusted 扱い（trust_level None）

このロジックに **「親ディレクトリの prefix を辿る」処理が存在しません**。([GitHub][1])

したがって、

* `projects."/srv/mount"=trusted` でも
  `project_root_key` が `/srv/mount/<repo>` なら **一致しないので untrusted**
* `projects."/srv/mount/<repo>"=trusted` を追加すると一致して trusted

という現象はそのまま説明できます。([GitHub][1])

## 2) “完全一致のみ” が意図されている可能性（セキュリティ設計）

この設計は、セキュリティ観点では自然です。

* prefix trust（`/srv/mount` を trust したら配下全部 trust）は、
  **同じ親ディレクトリ配下に別の untrusted なチェックアウトや生成物が混ざっても全部 trust になる**
* さらに symlink/バインドマウントが絡むと、prefix 判定は **境界が曖昧になりやすい**

Codex は “untrusted のとき project config を disabled にする” 方針を明記しているので、trust 境界を曖昧にしないために、prefix 継承を避けているのは合理的です。([GitHub][1])

---

# C) skills の探索・ロード条件（repo-scope skills が見えない理由）

## 1) repo-scope skills の場所とスコープ

公式ドキュメントでは、skills は複数スコープ（system/user/repo 等）から読み込まれ、repo スコープの一例として **`$REPO_ROOT/.codex/skills`** が示されています。([OpenAI Developers][2])

また changelog でも、`.codex/` フォルダを **cwd / 親ディレクトリ / repo root / user / system** からレイヤとしてロードする、と書かれています。([OpenAI Developers][3])

## 2) skills の root は「config layer のフォルダ + `/skills`」

GitHub issue 側にも明記がありますが、skills の root は **config layer folders + `/skills`** から作られます。([GitHub][4])
（＝ `.codex` が config folder として認識されると、その配下の `skills/` が探索対象になる）

Zenn のコードリーディング記事も、`skill_roots_from_layer_stack_inner` が設定レイヤスタックから root リストを作り、そこを走査して SKILL.md を発見する流れを説明しています。([Zenn][5])

## 3) trust が skills ロードに関与する分岐点

ここがあなたの症状の直接原因です。

* project の config layer（cwd や `.codex/config.toml` 等）は **untrusted のとき “disabled”** として stack に積まれる ([GitHub][1])
* trust 判定は上で示した通り **dir / project_root / repo_root の “キー一致”**で決まり、親 `/srv/mount` は見ない ([GitHub][1])
* skills root は config layer folders 由来なので、**該当する `.codex` レイヤが disabled なら、その `skills/` も実質的に探索対象から落ちる** ([GitHub][4])

結果として、

* system skills（例：`/etc/codex` 配下）は見える
* repo-scope（`/srv/mount/<repo>/.codex/skills`）は、`/srv/mount/<repo>` が trusted 扱いにならないと見えない

が成立します。([GitHub][1])

補足：`/etc/codex/` は「config folder」として扱われ、`skills/` や `rules/` 等のサブフォルダも尊重する、とコメントされています。よって system skills が見えるのは自然です。([GitHub][1])

---

# D) ベストプラクティス提案（単一コンテナ内・複数 worktree 必須、かつ `projects` 増殖を抑える）

あなたの要件と Codex の実装制約（prefix trust なし）を両立する現実解は、次のいずれかです。おすすめは **D-1** です。

---

## D-1) 推奨：project_root_markers を「コンテナの mount root に寄せる」方式（trust 1エントリで全 worktree を安定化）

### 発想

`projects` が prefix 継承しないなら、**「trust 照合に使われる project_root_key 自体を /srv/mount にしてしまう」**のが最も堅いです。

実装上、trust 判定は `project_root_key` を見ます。([GitHub][1])
なので `find_project_root()` が `/srv/mount` を返すようにできれば、`projects."/srv/mount"=trusted` が効くようになります。

### 実現方法

1. `/srv/mount` に marker ファイル（例：`.agent-sandbox-root`）を置く
2. コンテナ環境の system レイヤ `/etc/codex/config.toml` で `project_root_markers` をその marker のみにする
3. 同じ system レイヤで `projects."/srv/mount".trust_level="trusted"` を設定する

### 具体例：/etc/codex/config.toml（コンテナ専用）

```toml
# /etc/codex/config.toml（container image か compose mount で配布）
project_root_markers = [".agent-sandbox-root"]

[projects."/srv/mount"]
trust_level = "trusted"
```

ポイント：

* `.git` を markers から **外す**のが重要です。デフォルトの `.git` を残すと、worktree root（`/srv/mount/<repo>`）が project root になりやすく、結局 trust が分散します。([GitHub][1])
* system レイヤ（`/etc/codex/config.toml`）は **ホスト側の `~/.codex/config.toml` を汚さない**ため、あなたの「外部ツールが user config を機械編集したくない」に合致します。([GitHub][1])

### Docker Compose 例（概念）

* `/etc/codex/` を作れるようにした上で、system config を read-only で渡す
* コンテナ起動時に marker を `touch` する（ホストの mount root にも残る）

```yaml
services:
  codex:
    volumes:
      - ./codex-system-config.toml:/etc/codex/config.toml:ro
      - ${HOST_WORKTREE_LCA}:/srv/mount
    entrypoint: ["bash", "-lc", "touch /srv/mount/.agent-sandbox-root; exec \"$@\"", "--"]
    command: ["bash"]  # いつものシェル
```

### 期待される効果

* `projects` は **`/srv/mount` の 1 エントリ**で固定
* `/srv/mount/<repo>` 配下のどの worktree でも、project root は `/srv/mount` になり、trust が安定
* repo-scope skills（`/srv/mount/<repo>/.codex/skills`）が **全 worktree で安定して見える**（project config layer が disabled にならないため）([GitHub][1])
* さらに、必要なら `/srv/mount/.codex/skills` に **“全 worktree 共通 skills”** を置く設計も可能
  （repo 固有 skills は各 repo の `.codex/skills` に置く。重複名の解決は優先度で決まる設計。）([Zenn][5])

### セキュリティ/最小権限の観点（トレードオフ）

この方式は、**/srv/mount 配下を 1 つの trust 境界として扱う**ことを意味します。
よって最小権限を崩さないためには：

* `/srv/mount` に「信頼しないチェックアウト」や「第三者が書き込める領域」を混ぜない
* “worktree 群の LCA” ディレクトリを **Codex 専用ワークスペース**として運用する

この運用が守れないなら、Codex 側に prefix trust が無い以上、**結局 repo ごとに trust を分けるしかありません**（＝`projects` 増殖は避けられない）。

---

## D-2) 公式機構寄せ：起動時の runtime config override（`--config` 系）で trust を付与する（ファイルを編集しない）

config loader のコメントに「runtime e.g., `--config` flags」が明示されています。([GitHub][1])
したがって、agent-sandbox 側が **Codex 起動時だけ** trust と markers を override するのは、設計として筋が良いです（config.toml の機械編集を避けられる）。

ただし、正確な CLI 構文（`--config key=value` の TOML 値の書き方など）はバージョンで変わり得るので、採用するなら **Codex の該当バージョンの公式 config docs/ヘルプ出力に合わせて固定**してください。([GitHub][1])

（方針としては D-1 と同じく、`project_root_markers=[".agent-sandbox-root"]` と `projects."/srv/mount".trust_level="trusted"` を “その起動にだけ” 注入する。）

---

## D-3) 切り分け強化：コンテナ内の CODEX_HOME をホストと分離する

あなたは現在 `~/.codex/config.toml` をホストと共有していますが、**container-only の CODEX_HOME** を使えば、

* host 側の codex 設定とコンテナ側の trust/markers を完全に分離できる
* “コンテナのシステムレイヤ /etc/codex” と合わせて、より壊れにくい

というメリットがあります（ただし「共有したい設定」もあるはずなので、運用判断になります）。([GitHub][1])

---

# まとめ（あなたの観測事実への回答を一言で）

* `/srv/mount` trusted が `/srv/mount/<repo>` に継承されないのは、**trust 判定が prefix/祖先継承ではなく、dir / project_root / repo_root の “完全一致” しか見ていない実装だから**です。([GitHub][1])
* repo-scope skills が見えないのは、**untrusted だと project config layer が disabled になり、その layer 由来の `skills/` が探索対象から落ちる**ためです。([GitHub][4])
* 単一コンテナ内で複数 worktree を並行しつつ `projects` を増殖させない最も堅い解は、**project_root_markers を container 専用に調整して project root を /srv/mount に固定し、/srv/mount を 1 回だけ trusted にする**ことです。([GitHub][1])

[1]: https://raw.githubusercontent.com/openai/codex/main/codex-rs/core/src/config_loader/mod.rs "https://raw.githubusercontent.com/openai/codex/main/codex-rs/core/src/config_loader/mod.rs"
[2]: https://developers.openai.com/codex/skills/ "https://developers.openai.com/codex/skills/"
[3]: https://developers.openai.com/codex/changelog/ "https://developers.openai.com/codex/changelog/"
[4]: https://github.com/openai/codex/issues/9695 "https://github.com/openai/codex/issues/9695"
[5]: https://zenn.dev/takiko/articles/codex-cli-agent-skills-implementation "https://zenn.dev/takiko/articles/codex-cli-agent-skills-implementation"


---