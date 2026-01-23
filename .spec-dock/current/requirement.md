---
種別: 要件定義書
機能ID: "FEAT-006"
機能名: "NPM グローバルツール共有（1回の更新を全コンテナに反映）"
関連Issue: ["TBD"]
状態: "approved"
作成者: "Codex"
最終更新: "2026-01-23"
---

# FEAT-006 NPM グローバルツール共有（1回の更新を全コンテナに反映） — 要件定義（WHAT / WHY）

## 目的（ユーザーに見える成果 / To-Be） (必須)
- Codex CLI / Claude Code / Gemini CLI / OpenCode などの **NPM グローバルCLI** を、ホスト上で1回更新するだけで、この sandbox CLI が管理する全コンテナで同じ更新結果を利用できる。
- これにより「コンテナごとに更新」「更新のための重いイメージ再ビルド」を避け、運用コストと待ち時間を削減する。

## 背景・現状（As-Is / 調査メモ） (必須)
- 現状の挙動（事実）:
  - `Dockerfile` は `NPM_CONFIG_PREFIX=/usr/local/share/npm-global` を設定し、ビルド時に `npm run install-global` でグローバルCLIを導入している。 (`Dockerfile`:118-127)
  - `package.json` の `dependencies` は各CLIが `"latest"` であり、意図としては“最新のCLIを利用したい”寄りの運用になっている。 (`package.json`:14-23)
  - `docker-compose.yml` は `.agent-home` 配下を多数 bind mount するが、NPMグローバル（`/usr/local/share/npm-global`）や NPM cache は永続化/共有していない。 (`docker-compose.yml`:35-50)
  - `host/sandbox` は `COMPOSE_PROJECT_NAME` を mount-root/workdir から計算し、複数コンテナ（= 複数 compose project）を同時運用できる。 (`host/sandbox`)
- 現状の課題（困っていること）:
  - グローバルCLIの更新が必要な場合、ビルドキャッシュの事情により「更新が反映されない」/「`--no-cache` で全層をやり直して非常に遅い」/「複数コンテナ分で冗長」になりやすい。
  - “更新したい対象”は主に NPM グローバルCLIだが、現状は“イメージ全体の再ビルド”に引きずられて時間がかかる。
- 再現手順（最小で）:
  1) 2つ以上の sandbox コンテナを別 mount-root/workdir で起動する。
  2) どちらも `codex --version` 等の CLI バージョンを確認する。
  3) CLI を更新したい場合、現状は（多くの場合）各環境で更新手順が必要になる。
- 観測点（どこを見て確認するか）:
  - ホスト側: `sandbox tools update`（新設予定）の実行ログ/終了コード
  - コンテナ側: `codex --version`, `claude --version`, `gemini --version`, `opencode --version` の一致
  - 共有状態: 共有ストレージ（ボリューム）にCLI実体が入っていること
- 実際の観測結果（貼れる範囲で）:
  - Input/Operation: `Dockerfile`, `docker-compose.yml`, `package.json`, `host/sandbox` の現状確認
  - Output/State: NPMグローバルCLIがイメージビルドに内包され、compose project（= コンテナ単位）で更新作業が分断されやすい
- 情報源（ヒアリング/調査の根拠）:
  - ヒアリング: 「更新対象は NPM の CLI 群」「複数コンテナがあり、それぞれを更新するのが冗長」「`--no-cache` ビルドは非常に遅い」
  - コード: `Dockerfile`, `docker-compose.yml`, `package.json`, `host/sandbox`

## 対象ユーザー / 利用シナリオ (任意)
- 主な利用者（ロール）: このリポジトリの `sandbox` CLI 利用者
- 代表的なシナリオ:
  - 複数プロジェクトを別コンテナで起動しているが、CLI ツール更新は1回で済ませたい。
  - “更新は必要な時だけ”手動で行い、通常の `sandbox up` / `sandbox shell` は速く保ちたい。

## スコープ（暴走防止のガードレール） (必須)
- MUST（必ずやる）:
  - NPMグローバルCLIの実体（`/usr/local/share/npm-global` 配下）を、**全 sandbox コンテナ間で共有される永続ストレージ**に配置できるようにする。
  - ホスト側から **1回の操作で更新**できる導線を用意する（例: `sandbox tools update`）。
  - 更新は原則「手動トリガー」であり、通常起動時に毎回アップデートしない。
- MUST NOT（絶対にやらない／追加しない）:
  - 起動のたびに自動で NPM 更新する（ネットワーク/時間コストが増えるため）。
  - テストで実Dockerを呼び出す（既存方針に従いスタブで検証する）。
  - 既存の `sandbox shell/up/...` の意味を変える（互換性を壊す変更はしない）。
- OUT OF SCOPE（今回やらない）:
  - CLI ツール群のバージョンピン留め（`latest`→固定化）や、リリース管理の仕組み化
  - マルチホスト（別PC）まで含む共有（今回は同一ホスト内の共有まで）
  - 任意のNPMパッケージを選択できるGUI/設定画面追加

## 非交渉制約（守るべき制約） (必須)
- 既存 CLI（`sandbox shell/up/build/stop/down/status/name/codex`）の互換性は維持する（追加はOK、破壊はNG）。
- テストは既存方針（docker/git をスタブ化）を維持し、実Dockerやネットワークに依存しない。
- 共有ストレージは「全 compose project（= 複数コンテナ）で同一」を保証する（“プロジェクトごとに別ボリューム”は禁止）。

## 前提（Assumptions） (必須)
- CLI 更新対象は `package.json` の `install-global` で導入するグローバルCLI群である。
- 複数コンテナは同一ホスト上の Docker Desktop/Engine 上で動作する。
- “更新を1回で済ませたい”範囲は、この `sandbox` CLI が起動するコンテナ群に限定する。

## 判断材料/トレードオフ（Decision / Trade-offs） (任意)
- 論点: 共有ストレージの方式（named volume vs bind mount）
  - 選択肢A: Docker named volume（固定名）
    - Pros: macOS でも高速、compose project を跨いで共有しやすい、ホストのディレクトリ依存が減る
    - Cons: ホストから中身を直接見づらい、Docker側の管理（削除等）が必要
  - 選択肢B: ホスト bind mount（例: `.agent-home/npm-global`）
    - Pros: 中身が見える、ホスト側でバックアップ/掃除しやすい
    - Cons: macOS では I/O が遅くなりがち、clone パスに依存
  - 推奨案（暫定）: 選択肢A（固定名の named volume）
  - 理由: “更新を全コンテナに即反映”と“速度”の両立に最も寄与するため

## リスク/懸念（Risks） (任意)
- R-001: 共有ボリューム導入により、初回はCLIが未導入状態になる可能性（影響: 初回起動で `codex` 等が無い / 対応: 初回導入手順を明確化、または初回のみ bootstrap を実施）
- R-002: 共有ボリュームの破損/競合（同時更新）リスク（影響: CLI 実体が壊れる / 対応: update コマンドにロック/排他を入れる）

## 受け入れ条件（観測可能な振る舞い） (必須)
- AC-001:
  - Actor/Role: sandbox 利用者（ホスト側）
  - Given: 異なる mount-root/workdir で2つ以上の sandbox コンテナが存在する
  - When: 利用者が1回だけ “ツール更新” 操作を実行する（例: `sandbox tools update`）
  - Then: すべての sandbox コンテナで、NPMグローバルCLIが同じ共有ストレージを参照し、更新結果が利用できる
  - 観測点（UI/HTTP/DB/Log など）: コンテナ内 `codex/claude/gemini/opencode --version`、共有ストレージの内容
- AC-002:
  - Actor/Role: sandbox 利用者（ホスト側）
  - Given: 共有ストレージが設定されている
  - When: 利用者が通常の `sandbox up` / `sandbox shell` を実行する
  - Then: 起動のたびに NPM 更新は自動実行されない（更新は手動トリガーのみ）
  - 観測点: 起動ログ/コマンド実行ログ、`npm` が走らないこと
  - 権限/認可条件: 該当なし
- AC-003:
  - Actor/Role: sandbox 利用者（ホスト側）
  - Given: 共有ストレージが空（初回）である
  - When: 利用者が手順（初回導入 or bootstrap）に従う
  - Then: 必要なグローバルCLIが利用可能になる
  - 観測点: `codex --version` 等が実行できる
  - 権限/認可条件: 該当なし

### 入力→出力例 (任意)
- EX-001:
  - Input: `sandbox tools update`
  - Output: update が成功し、次回以降どの sandbox コンテナでも更新後の CLI を利用できる
- EX-002:
  - Input: `sandbox shell`（通常起動）
  - Output: 自動更新は走らず、共有ストレージ上の CLI をそのまま利用する

## 例外・エッジケース（仕様として固定） (必須)
- EC-001:
  - 条件: `sandbox tools update` が同時に複数起動された
  - 期待: 共有ストレージが破損しない（片方が待機 or 明確なエラーで終了する）
  - 観測点: update の終了コード/ログ、共有ストレージの整合性
- EC-002:
  - 条件: `sandbox tools update` 実行中に NPM エラー（ネットワーク、レジストリ、依存解決）が発生した
  - 期待: コマンドは非0終了し、次回の update で再試行できる（“成功した”扱いにしない）
  - 観測点: 終了コード、ログ、（ある場合）初回導入フラグの未作成

## 用語（ドメイン語彙） (必須)
- TERM-001: sandbox コンテナ = `host/sandbox` が `docker compose` で起動する `agent-sandbox` サービスのコンテナ
- TERM-002: 共有NPMグローバル = `/usr/local/share/npm-global` を “全 compose project で同一” の永続ストレージとして扱うこと
- TERM-003: ツール更新 = `npm run install-global`（`package.json`）を実行してグローバルCLIを更新する操作

## 未確定事項（TBD / 要確認） (必須)
- Q-001:
  - 質問: 共有ストレージは named volume（固定名）でいくか、ホスト bind mount でいくか？
  - 選択肢:
    - A: named volume（固定名）
    - B: bind mount（`.agent-home/npm-global` 等）
  - 推奨案（暫定）: A
  - 影響範囲: AC-001/003, EC-001, 設計/テスト方針
- Q-002:
  - 質問: 初回（共有ストレージが空）時の導入は自動bootstrapにするか、手動updateを必須にするか？
  - 選択肢:
    - A: 初回のみ自動bootstrap（以後は手動update）
    - B: 初回も手動update（ドキュメントで誘導）
  - 推奨案（暫定）: B（シンプルに “手動updateのみ” で開始し、必要ならAを追加）
  - 影響範囲: AC-003, EC-001/002, エントリポイント/CLI設計
- Q-003:
  - 質問: `sandbox build` のデフォルト（キャッシュ利用）を見直すか？
  - 選択肢:
    - A: 現状維持（`sandbox build` のデフォルト挙動は変更しない）
    - B: キャッシュ利用をデフォルトに戻し、`--no-cache` は明示指定にする
  - 推奨案（暫定）: B（ツール更新がビルドから分離できるため）
  - 影響範囲: 開発体験（待ち時間）、既存CLI互換

## 完了条件（Definition of Done） (必須)
- すべてのAC/ECが満たされる
- 未確定事項が解消される（残す場合は「残す理由」と「合意」を明記）
- MUST NOT / OUT OF SCOPE を破っていない（追加機能を入れていない）

## 省略/例外メモ (必須)
- 該当なし
