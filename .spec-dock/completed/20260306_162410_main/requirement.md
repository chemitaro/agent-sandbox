---
種別: 要件定義書
機能ID: "CHORE-NODE-LTS-001"
機能名: "Docker イメージで導入する Node.js を 20 系固定から Active LTS へ更新"
関連Issue: ["N/A"]
状態: "draft"
作成者: "Codex CLI"
最終更新: "2026-03-07"
---

# CHORE-NODE-LTS-001 Docker イメージで導入する Node.js を 20 系固定から Active LTS へ更新 — 要件定義（WHAT / WHY）

## 目的（ユーザーに見える成果 / To-Be） (必須)
- Docker イメージ内で導入される Node.js が 20 系固定ではなく、2026-03-07 時点の最新安定版解釈である Active LTS 系になる。
- 利用者は追加設定なしで、より新しい安定版 Node.js を前提に環境を起動できる。

## 背景・現状（As-Is / 調査メモ） (必須)
- 現状の挙動（事実）:
  - `Dockerfile` では NodeSource の `setup_20.x` を実行しており、Node.js 20 系に固定されている。
  - `package.json` の `engines.node` は `>=20.0.0` であり、20 より新しい LTS 系へ更新しても直ちに矛盾しない。
  - 2026-03-07 時点の Node.js 公式リリース情報では `24.x` が Active LTS、`25.x` が Current である。
- 現状の課題（困っていること）:
  - Docker イメージの Node.js が古く、最新安定版を使いたいというユーザー要望を満たせていない。
  - `setup_20.x` の固定により、意図せず旧系列に留まり続ける。
- 再現手順（最小で）:
  1) `Dockerfile` を開く
  2) `setup_20.x` を参照していることを確認する
  3) イメージをビルドしてコンテナ内で `node --version` を確認すると 20 系になる
- 観測点（どこを見て確認するか）:
  - 設定:
    - `Dockerfile` の NodeSource セットアップ URL
    - Node.js バージョン説明コメント
  - CLI/Log:
    - コンテナ内の `node --version`
    - 既存 Bash テスト結果
- 実際の観測結果（貼れる範囲で）:
  - `Dockerfile:11-14`
    - `# Install Node.js 20`
    - `curl -fsSL https://deb.nodesource.com/setup_20.x | bash -`
  - `package.json:6-8`
    - `"node": ">=20.0.0"`
- 情報源（ヒアリング/調査の根拠）:
  - コード:
    - `/srv/mount/box/Dockerfile:11` - Node.js 20 固定コメント
    - `/srv/mount/box/Dockerfile:13` - `setup_20.x` 実行箇所
    - `/srv/mount/box/package.json:6` - `engines.node >=20.0.0`
  - 調査:
    - Node.js 公式 previous releases（2026-03-07 時点で `24.x = Active LTS`, `25.x = Current`）
    - NodeSource 配布スクリプト（`setup_lts.x` / `setup_current.x` の実体確認）

## 対象ユーザー / 利用シナリオ (任意)
- 主な利用者（ロール）:
  - このリポジトリの Docker ベース開発環境を使う開発者
- 代表的なシナリオ:
  - `sandbox up` で環境を作成し、コンテナ内で Node.js ベースの CLI を利用する

## スコープ（暴走防止のガードレール） (必須)
- MUST（必ずやる）:
  - Docker イメージの Node.js インストール設定を 20 系固定から 24 系固定へ更新する
  - 「最新安定版」の意味を Active LTS として固定する
  - 退行防止として、Dockerfile の Node.js 系列を検査する Bash テストを追加または更新する
  - イメージ再ビルド後に `node --version` が `v24.` 系で始まることを確認する
- MUST NOT（絶対にやらない／追加しない）:
  - `Current` 系 (`25.x`) へ上げない
  - `package.json` の依存や CLI の導入対象を変更しない
  - Docker Compose のサービス構成や `host/sandbox` の CLI 仕様を変えない
- OUT OF SCOPE（今回やらない）:
  - npm パッケージの一斉アップデート
  - `package.json` の `engines` を厳密に `24.x` へ狭める変更
  - 複数 Node バージョン切替機構（nvm/fnm/volta 等）の導入

## 非交渉制約（守るべき制約） (必須)
- 既存の Docker ベース開発フロー（`sandbox up/shell/status/down`）を壊さないこと
- 既存テスト（少なくとも `bash tests/sandbox_cli.test.sh`）が成功すること
- 「最新安定版」は 2026-03-07 時点の公式情報に基づき Active LTS と解釈すること
- 再現性を優先し、可変エイリアスではなく major 固定のセットアップスクリプトを使うこと

## 前提（Assumptions） (必須)
- 利用中の Ubuntu 24.04 ベースイメージで NodeSource の 24 系セットアップが利用できる
- 既存 CLI 群は Node.js 24 系でも動作する
- `engines.node >=20.0.0` は 24 系利用を許容する

## 判断材料/トレードオフ（Decision / Trade-offs） (任意)
- 論点: 「最新安定版」を `Current` と `Active LTS` のどちらで解釈するか
  - 選択肢A: `Active LTS`（24.x）
    - Pros: Node.js 公式の production 向け推奨に沿う、互換性変化が比較的穏やか
    - Cons: 常に絶対最新 major にはならない
  - 選択肢B: `Current`（25.x）
    - Pros: 最も新しい major を使える
    - Cons: 本番安定性より先行追従を優先することになり、変化が大きい
  - 決定: 選択肢A（`Active LTS`）
  - 理由: ユーザーの「最新安定版」という表現と Node.js 公式の production 推奨が一致するため
- 論点: NodeSource の可変エイリアスを使うか、major 固定にするか
  - 選択肢A: `setup_lts.x`
  - 選択肢B: `setup_24.x`
  - 決定: 選択肢B（major 固定）
  - 理由: 将来の LTS 切替タイミングで予期せぬ変化を避け、再現性を優先するため

## リスク/懸念（Risks） (任意)
- R-001: Node.js 24 系で一部 CLI の互換問題が出る可能性（影響: 中 / 対応: 今回は導入系列更新のみを対象とし、必要なら別タスクで `npm run verify` を実施する）
- R-002: NodeSource 配布内容の変化でビルドが失敗する可能性（影響: 低〜中 / 対応: `setup_24.x` 固定とビルド検証）

## 受け入れ条件（観測可能な振る舞い） (必須)
- AC-001:
  - Actor/Role: 開発者
  - Given: リポジトリの Dockerfile を参照できる
  - When: Node.js のインストール設定を確認する
  - Then: `setup_20.x` は存在せず、`setup_24.x` を使っている
  - 観測点（UI/HTTP/DB/Log など）: `Dockerfile` の該当行
- AC-002:
  - Actor/Role: 開発者
  - Given: 更新後のイメージをビルドしてコンテナを起動できる
  - When: コンテナ内で `node --version` を実行する
  - Then: 出力が `v24.` で始まる
  - 観測点（UI/HTTP/DB/Log など）: `node --version` の出力
- AC-003:
  - Actor/Role: 開発者/CI
  - Given: Bash テストを実行できる
  - When: Node.js 系列の静的検査テストと既存 CLI テストを実行する
  - Then: 成功する
  - 観測点（UI/HTTP/DB/Log など）: テスト結果（exit code / ログ）

### 入力→出力例 (任意)
- EX-001:
  - Input: `grep -F "setup_24.x" Dockerfile`
  - Output: 一致あり
- EX-002:
  - Input: `node --version`
  - Output: `v24.x.y`

## 例外・エッジケース（仕様として固定） (必須)
- EC-001:
  - 条件: NodeSource の可変エイリアス (`setup_lts.x`) が将来別 major を指す
  - 期待: 今回はそれを採用せず `setup_24.x` に固定する
  - 観測点（UI/HTTP/DB/Log など）: `Dockerfile` の URL
- EC-002:
  - 条件: `package.json` は `>=20` のままである
  - 期待: 24 系利用でも矛盾せず、`engines` 自体は変更しない
  - 観測点: `package.json` とテスト結果

## 用語（ドメイン語彙） (必須)
- TERM-001: Active LTS = Node.js 公式が production 向けに自然な選択として扱う安定系列
- TERM-002: Current = 最新 major だが LTS ではない先行系列
- TERM-003: NodeSource setup script = Debian/Ubuntu へ Node.js apt リポジトリを設定するスクリプト

## 未確定事項（TBD / 要確認） (必須)
- Q-001（解消済み / 2026-03-07 ユーザー合意）:
  - 質問: 「最新安定版」はどの追従方針で固定するか
  - 決定: `Active LTS`
  - 影響範囲: AC-001, AC-002, 設計, テスト方針

## 完了条件（Definition of Done） (必須)
- すべての AC/EC が満たされる
- Docker イメージの Node.js 導入系列が 24 系固定へ更新される
- 既存フローと既存テストを壊していない

## 省略/例外メモ (必須)
- 該当なし
