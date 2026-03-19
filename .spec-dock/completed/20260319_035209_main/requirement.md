---
種別: 要件定義書
機能ID: "FEATURE-COPILOT-CLI-INTEGRATION"
機能名: "GitHub Copilot CLI を sandbox ツールチェーンへ統合する"
関連Issue: []
状態: "draft"
作成者: "Codex"
最終更新: "2026-03-19"
---

# FEATURE-COPILOT-CLI-INTEGRATION GitHub Copilot CLI を sandbox ツールチェーンへ統合する — 要件定義（WHAT / WHY）

## 目的（ユーザーに見える成果 / To-Be） (必須)
- このツールの Docker サンドボックス上で GitHub Copilot CLI を既存の Codex CLI / Claude Code / Gemini CLI / OpenCode と同列に利用できるようにする。
- GitHub Copilot CLI が生成・利用するユーザー設定や関連ファイルを、ホスト側の `.agent-home` 配下から標準ディレクトリへ mount して永続化できるようにする。
- 既存の `sandbox codex` と同系統の操作感で、`sandbox copilot` から tmux 経由で Copilot CLI を起動できるようにする。

## 背景・現状（As-Is / 調査メモ） (必須)
- 現状の挙動（事実）:
  - このリポジトリは Docker コンテナ `agent-sandbox` を起動し、作業対象ディレクトリと `.agent-home` 配下のエージェント設定ディレクトリを bind mount する構成である。
  - 現時点で mount されるエージェント関連ディレクトリは `.claude`、`.codex`、`.gemini`、`.opencode`、`.opencode-data` と、その関連 cache である。
  - `package.json` のグローバルインストール対象は `@openai/codex`、`@anthropic-ai/claude-code`、`@google/gemini-cli`、`opencode-ai` であり、GitHub Copilot CLI は未統合である。
  - `host/sandbox` には `sandbox codex` 専用フローがあり、tmux セッション生成、`codex resume` 実行、競合引数の拒否、Trust 判定に基づく bootstrap/YOLO 切替までを提供している。
  - `sandbox tools update` は npm グローバルツール群を一括更新するが、その対象にも GitHub Copilot CLI は含まれていない。
- 現状の課題（困っていること）:
  - GitHub Copilot CLI をこのサンドボックス上で既存ツールと同じ運用方法で使えない。
  - Copilot CLI の設定・認証・LSP 設定などをホスト上で永続化するための `.agent-home` 連携が未実装である。
  - ツール更新・検証・ヘルプ・テストに Copilot CLI が反映されておらず、統合レベルが揃っていない。
- 再現手順（最小で）:
  1. `sandbox tools update` を実行して共有 npm グローバルツールを更新する。
  2. コンテナ内で `copilot --version` または `which copilot` を確認する。
  3. `sandbox --help` および `sandbox tools --help` を確認する。
  4. `.agent-home` 配下を確認する。
- 観測点（どこを見て確認するか）:
  - UI: なし
  - HTTP: なし
  - DB: なし
  - Log:
    - `tests/sandbox_cli.test.sh` の compose/tmux stub ログ
    - `sandbox --help` / `sandbox tools --help` / `sandbox copilot --help`
    - コンテナ内の `copilot --version`
    - `.agent-home` 配下の作成ディレクトリ
- 実際の観測結果（貼れる範囲で）:
  - Input/Operation:
    - `rg -n "codex|claude|gemini|opencode|agent-home" -S .`
    - `cat package.json`
    - `sed -n '1,220p' docker-compose.yml`
    - `sed -n '1,220p' Dockerfile`
    - `sed -n '1,1460p' host/sandbox`
  - Output/State:
    - `docker-compose.yml` は `.agent-home/.claude`、`.agent-home/.codex`、`.agent-home/.gemini`、`.agent-home/.opencode` などを mount しているが、Copilot 用 mount は無い。
    - `Dockerfile` は `/home/node/.claude`、`/home/node/.codex`、`/home/node/.gemini`、`/home/node/.config/opencode` 等を事前作成しているが、Copilot 用ディレクトリは無い。
    - `package.json` の `install-global` / `verify` に Copilot CLI は無い。
    - `host/sandbox` の help / `ensure_agent_home_dirs` / `tools update` / `codex` サブコマンド群に Copilot CLI は無い。
- 情報源（ヒアリング/調査の根拠）:
  - ヒアリング:
    - ユーザー回答（2026-03-19）:
      - `sandbox copilot` のような専用サブコマンドを追加したい
      - tmux 経由で起動したい
      - `COPILOT_HOME` 等で別ディレクトリ指定はせず、GitHub Copilot CLI の標準ディレクトリを使いたい
      - ただし標準ディレクトリに作られるファイル一式は `.agent-home` から mount して永続化したい
  - ドキュメント:
    - GitHub Docs, "Installing GitHub Copilot CLI"（2026-03-19 確認）:
      - npm インストールは `npm install -g @github/copilot`
      - npm インストール時の前提は Node.js 22+
      - URL: `https://docs.github.com/copilot/how-tos/set-up/install-copilot-cli`
    - GitHub Copilot CLI README（2026-03-19 確認）:
      - 起動コマンドは `copilot`
      - ユーザーレベルの LSP 設定は `~/.copilot/lsp-config.json`
      - URL: `https://github.com/github/copilot-cli`
  - コード:
    - `docker-compose.yml`（bind mount の現行仕様）
    - `Dockerfile`（CLI 設定ディレクトリの初期作成）
    - `package.json`（グローバルツールのインストール・検証）
    - `host/sandbox`（CLI サブコマンド、`.agent-home` 初期化、tools update、codex 統合）
    - `tests/sandbox_cli.test.sh`（CLI 仕様テスト）

## 対象ユーザー / 利用シナリオ (任意)
- 主な利用者（ロール）:
  - この sandbox ツールを使って各種コーディングエージェントを安全に起動する開発者
- 代表的なシナリオ:
  - `sandbox tools update` で Copilot CLI を含む共有ツールをインストールする
  - `sandbox copilot` で tmux セッションを生成または再利用し、コンテナ内で Copilot CLI を起動する
  - Copilot CLI のログイン情報や `~/.copilot/*` を `.agent-home/.copilot` 経由で永続化する

## スコープ（暴走防止のガードレール） (必須)
- MUST（必ずやる）:
  - GitHub Copilot CLI を Docker イメージと `sandbox tools update` の共有ツール群へ追加する
  - Copilot CLI の標準ユーザーディレクトリ `~/.copilot` を、ホスト側 `.agent-home/.copilot` から bind mount する
  - `host/sandbox` に `sandbox copilot [options] -- [copilot args...]` サブコマンドを追加し、tmux セッション経由で `copilot` を起動できるようにする
  - `help`、`tools update`、`.agent-home` 初期化、Docker mount、テストを Copilot 対応に更新する
  - 既存 CLI 群の挙動を壊さない
- MUST NOT（絶対にやらない／追加しない）:
  - `COPILOT_HOME` などで標準ディレクトリを別パスへ変更する設計にしない
  - Copilot CLI について `~/.copilot` 以外の XDG/config/cache mount を推測で追加しない
  - Copilot CLI の認証フローを独自実装しない
  - 既存の Codex 専用 Trust/YOLO/bootstrap 判定を Copilot CLI に流用しない
  - GitHub Copilot CLI 以外の新規ツールを同時に追加しない
- OUT OF SCOPE（今回やらない）:
  - Copilot CLI の詳細な slash command 運用ガイド整備
  - Copilot CLI の enterprise policy や課金設定の管理
  - LSP サーバー自体の自動インストール
  - 既存 `sandbox codex` の仕様変更

## 非交渉制約（守るべき制約） (必須)
- 既存の `.agent-home` ベースの永続化設計と整合すること
- Docker コンテナ内では GitHub Copilot CLI の標準ユーザーディレクトリを使うこと
- `sandbox tools update` の更新対象と `npm run verify` の検証対象を一致させること
- `sandbox copilot` は `sandbox codex` と同様に tmux セッションを自動生成・再利用すること
- 既存テストの deterministic な stub ベース戦略を維持し、実 Docker/Git 呼び出しに依存しないこと
- 既存 CLI の挙動を変更する場合は、互換性維持または明示的な help 更新を行うこと

## 前提（Assumptions） (必須)
- 既存 Dockerfile は Node.js 24 を導入しており、GitHub Copilot CLI の npm 前提 Node.js 22+ を満たす
- GitHub Copilot CLI のユーザー設定ファイル群は `~/.copilot` 配下に集約される
- `copilot` コマンドは npm グローバルインストール後に PATH 上で利用可能になる
- Copilot CLI の利用者は別途有効な GitHub Copilot 利用権限を持つ

## 判断材料/トレードオフ（Decision / Trade-offs） (任意)
- 論点: Copilot CLI の永続化対象をどこまで mount するか
  - 選択肢A: `~/.copilot` ディレクトリ全体を `.agent-home/.copilot` から mount する
  - 選択肢B: `config.json` や `lsp-config.json` のみを個別 mount する
  - 決定: 選択肢A
  - 理由: ユーザー要望が「インストール時に生成されるディレクトリやファイル一式をローカルへ mount」であり、標準ディレクトリ全体を扱う方が既存ツール群の設計と一致する
- 論点: Copilot CLI 起動フロー
  - 選択肢A: `sandbox shell` から手動実行のみサポート
  - 選択肢B: `sandbox copilot` を追加し tmux 経由で起動
  - 決定: 選択肢B
  - 理由: ユーザーが Codex と同水準の統合を要求しているため

## リスク/懸念（Risks） (任意)
- R-001: GitHub Copilot CLI は発展途上のため、将来設定ディレクトリや起動引数が変わる可能性がある（影響: 維持コスト増 / 対応: 標準ディレクトリと基本起動のみを固定し、過剰な独自制御を避ける）
- R-002: Copilot CLI は Codex のような Trust/YOLO 概念を公開していないため、起動ラッパーの仕様を必要以上に複雑化できない（影響: 起動制御差異 / 対応: tmux と compose 起動に責務を限定する）

## 受け入れ条件（観測可能な振る舞い） (必須)
- AC-001:
  - Actor/Role: sandbox 利用者
  - Given: 共有 npm グローバルツールを更新可能な sandbox 環境がある
  - When: `sandbox tools update` を実行する
  - Then: GitHub Copilot CLI が既存 CLI 群と同じ更新フローに含まれ、コンテナ内で `copilot --version` が実行可能になる
  - 観測点（UI/HTTP/DB/Log など）: `package.json`、`sandbox tools update` の compose 実行ログ、`npm run verify`
  - 権限/認可条件（ある場合）: npm パッケージ取得が可能であること
- AC-002:
  - Actor/Role: sandbox 利用者
  - Given: sandbox ルート配下に `.agent-home` がある
  - When: `sandbox up` / `sandbox shell` / `sandbox copilot` の前処理を行う
  - Then: `.agent-home/.copilot` が作成され、コンテナ内の標準ディレクトリ `~/.copilot` に bind mount される
  - 観測点（UI/HTTP/DB/Log など）: `.agent-home` ディレクトリ、`docker-compose.yml`、`Dockerfile`
  - 権限/認可条件（ある場合）: なし
- AC-003:
  - Actor/Role: sandbox 利用者
  - Given: Docker と tmux が利用可能で、対象の workdir / mount-root が解決可能である
  - When: `sandbox copilot [options] -- [copilot args...]` を実行する
  - Then: tmux セッションを生成または再利用し、その内側で sandbox を起動した上でコンテナ内 workdir で `copilot [copilot args...]` を実行し、終了後は zsh に戻る
  - 観測点（UI/HTTP/DB/Log など）: tmux stub ログ、compose exec ログ、help 出力
  - 権限/認可条件（ある場合）: Docker と tmux が PATH 上で利用可能であること
- AC-004:
  - Actor/Role: sandbox 利用者
  - Given: `sandbox --help`、`sandbox tools --help`、`sandbox copilot --help` を参照する
  - When: Help を表示する
  - Then: Copilot CLI が既存ツール群の一員として help 文面に反映され、更新対象やサブコマンド一覧が理解できる
  - 観測点（UI/HTTP/DB/Log など）: stdout の help テキスト
  - 権限/認可条件（ある場合）: なし

### 入力→出力例 (任意)
- EX-001:
  - Input: `sandbox tools update --mount-root /path/to/repo --workdir /path/to/repo`
  - Output: compose run ログに Copilot CLI を含む `npm run install-global` が実行される
- EX-002:
  - Input: `sandbox copilot --mount-root /path/to/repo --workdir /path/to/repo/subdir -- --help`
  - Output: tmux セッション生成後、compose exec が `/srv/mount/.../subdir` を workdir にして `copilot --help` を起動する

## 例外・エッジケース（仕様として固定） (必須)
- EC-001:
  - 条件: `sandbox copilot` 実行時に tmux が存在しない
  - 期待: `sandbox codex` と同様に即座にエラー終了し、tmux 未導入を stderr に表示する
  - 観測点（UI/HTTP/DB/Log など）: stderr、終了コード
- EC-002:
  - 条件: `sandbox copilot --help` またはトップレベル help を表示する
  - 期待: `.env` や `.agent-home` を作成せず、副作用なく help だけを返す
  - 観測点（UI/HTTP/DB/Log など）: stdout、ファイルシステム、副作用の有無
- EC-005:
  - 条件: `sandbox copilot --mount-root <root> --workdir <dir> -- --help` を実行する
  - 期待: sandbox 側の help ではなく、`--` より後ろの引数として `copilot --help` がコンテナ内へそのまま渡される
  - 観測点（UI/HTTP/DB/Log など）: compose exec ログ、stdout
- EC-003:
  - 条件: `sandbox tools update` 実行時に update lock が存在する
  - 期待: 既存動作と同様にロック競合エラーで停止し、Copilot 追加によってロック動作は変化しない
  - 観測点（UI/HTTP/DB/Log など）: stderr、compose ログに `CMD=` が出ないこと
- EC-004:
  - 条件: Copilot CLI の標準ディレクトリにファイルが無い初回状態で sandbox を起動する
  - 期待: `.agent-home/.copilot` を先に作成して mount できる
  - 観測点（UI/HTTP/DB/Log など）: `.agent-home/.copilot` の存在

## 用語（ドメイン語彙） (必須)
- TERM-001: Agent Home = ホスト側 `.agent-home` 配下に置く、各 CLI の設定・認証・キャッシュ等の永続化ディレクトリ群
- TERM-002: 標準ディレクトリ = 各 CLI が環境変数による上書きを行わない場合に既定で使用するホーム配下のディレクトリ
- TERM-003: Copilot CLI = npm パッケージ `@github/copilot` により提供される `copilot` コマンド
- TERM-004: tmux ラッパー = `sandbox codex` と同様に、ホスト側で tmux セッションを張ってコンテナ実行を包む起動方式

## 未確定事項（TBD / 要確認） (必須)
- 該当なし

## 合意済み決定事項 (任意)
- D-001: `sandbox copilot` の CLI 契約は `sandbox copilot [options] -- [copilot args...]` とし、`--` より後ろは検証・禁止せず `copilot` に pass-through する
- D-002: `npm run verify` の Copilot 検証は `copilot --version` に固定する

## 完了条件（Definition of Done） (必須)
- すべてのAC/ECが満たされる
- 未確定事項が解消される、または残す場合は理由と合意が明記される
- MUST NOT / OUT OF SCOPE を破っていない

## 省略/例外メモ (必須)
- 該当なし
