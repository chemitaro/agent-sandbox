---
種別: 要件定義書
機能ID: "CHORE-TUI-COLOR-001"
機能名: "コンテナ内の色数（TERM/COLORTERM）を安定化して Codex CLI の表示崩れを解消"
関連Issue: ["N/A"]
状態: "draft"
作成者: "Codex CLI"
最終更新: "2026-02-26"
---

# CHORE-TUI-COLOR-001 コンテナ内の色数（TERM/COLORTERM）を安定化して Codex CLI の表示崩れを解消 — 要件定義（WHAT / WHY）

## 目的（ユーザーに見える成果 / To-Be） (必須)
- Docker コンテナ内で Codex CLI を起動したときに、端末が低色数（8色/16色）へフォールバックせず、少なくとも 256 色以上の色数前提で表示される。
- これにより「同じテーマなのにコンテナ内だけ見にくい/色が崩れる」問題を解消する。

## 背景・現状（As-Is / 調査メモ） (必須)
- 現状の挙動（事実）:
  - ホスト（macOS + Ghostty）で Codex CLI を使う場合は表示に問題がない。
  - Docker コンテナ内で Codex CLI を使うと、同一テーマでも色味が崩れて見にくい。
  - 現状のコンテナ内では `TERM=xterm` となっており、`tput colors` が `8` を返す（= 8色相当の能力広告になっている）。
  - `TERM=xterm-256color`（+必要なら `COLORTERM=truecolor`）にすると `tput colors` が `256` になり、色数問題は解消方向に向かう。
- 現状の課題（困っていること）:
  - コンテナ内の Codex CLI の配色が崩れ、可読性が著しく低下する。
- 再現手順（最小で）:
  1) `./host/sandbox up`
  2) `docker compose exec agent-sandbox /bin/zsh -lc 'echo TERM=$TERM; echo COLORTERM=$COLORTERM; tput colors'`
  3) `tput colors` が `8` になることを確認する
  4) `docker exec -it <container> /bin/zsh -lc 'echo TERM=$TERM; echo COLORTERM=$COLORTERM; tput colors'`
  5) `tput colors` が `8` になることを確認する
  6) コンテナ内で Codex CLI を起動し、表示が崩れていることを確認する
- 観測点（どこを見て確認するか）:
  - CLI/Log:
    - `echo "$TERM"`, `echo "$COLORTERM"`
    - `tput colors`
    - （必要に応じて）`infocmp "$TERM"` の成否
  - 設定:
    - `Dockerfile` / `docker-compose.yml` の差分（恒久化した設定が残っていること）
- 実際の観測結果（貼れる範囲で）:
  - ホスト（本リポの実行環境）:
    - `TERM=xterm-ghostty`
    - `COLORTERM=truecolor`
  - コンテナ（現状、`docker compose exec`）:
    - `TERM=xterm`
    - `COLORTERM=`（未設定）
    - `tput colors` → `8`
  - コンテナ（現状、`docker exec -it`）:
    - `TERM=xterm`
    - `COLORTERM=`（未設定）
    - `tput colors` → `8`
  - コンテナ（上書きして確認）:
    - `TERM=xterm-256color`
    - `COLORTERM=truecolor`
    - `tput colors` → `256`
- 情報源（ヒアリング/調査の根拠）:
  - ヒアリング:
    - ユーザー申告（Ghostty/コンテナ内で色味が変わる）
    - 参考: ChatGPT 共有メモ（`TERM/COLORTERM` 低下が主因、`xterm-256color` 推奨）
  - コード/設定:
    - `docker-compose.yml`（`tty: true` でも `TERM=xterm` になることの確認）
    - `Dockerfile`（コンテナのベース環境・パッケージ・ENV 方針の確認）
    - `host/sandbox`（`docker compose exec` を起点としていることの確認）
  - 実行ログ:
    - `docker compose exec ... tput colors` の観測値

## 対象ユーザー / 利用シナリオ (任意)
- 主な利用者（ロール）:
  - このリポジトリの `sandbox` 環境でコンテナを起動し、コンテナ内で Codex CLI を利用する開発者
- 代表的なシナリオ:
  - `./host/sandbox up` → `./host/sandbox shell` / `./host/sandbox codex` → コンテナ内で Codex CLI を利用する

## スコープ（暴走防止のガードレール） (必須)
- MUST（必ずやる）:
  - コンテナ内の端末能力（色数）を、少なくとも 256 色前提で安定して認識できるようにする
    - `TERM` を `xterm-256color` 相当にする（`tput colors=256` を保証）
    - `COLORTERM=truecolor` を設定し、TrueColor も検出できるようにする（常時設定）
  - 退行防止として、恒久化した設定（`TERM/COLORTERM`）が将来消えないことを担保するテストを追加/更新する（方法は `design.md` で確定）
  - 既存の `sandbox` CLI のコマンド体系・動作を維持する（`up/shell/codex/...`）
- MUST NOT（絶対にやらない／追加しない）:
  - Ghostty（端末エミュレータ）側の設定変更を前提にしない
  - `TERM=xterm-ghostty` を前提とした完全一致や、Ghostty 固有 terminfo の注入を必須にしない
  - Codex CLI 本体のテーマ仕様（配色定義）を変更しない
  - `.env` の機密値（API キー等）を変更/露出しない
- OUT OF SCOPE（今回やらない）:
  - “ローカルと完全一致” の見た目（パレット/ガンマまで含めた完全一致）
  - 端末背景色の取得（OSC 11 等）やテーマ自動切替などの高度機能
  - tmux/screen/ssh 等の特殊経路ごとの個別最適化（必要なら別タスク）

## 非交渉制約（守るべき制約） (必須)
- `./host/sandbox up|shell|codex|status|stop|down` の既存フローを壊さないこと
- コンテナは引き続き `user: node` で動作すること（権限/永続化の前提を崩さない）
- 既存テスト（少なくとも `bash tests/sandbox_cli.test.sh`）が成功すること
- セキュリティ: `.env` などの秘匿情報は要件/設計/ログに記載しない（マスキングを徹底する）

## 前提（Assumptions） (必須)
- 端末エミュレータ（Ghostty 等）は 256 色以上の表示能力を持つ
- コンテナの作り直し・再ビルドを許容する（Dockerfile/イメージ更新が可能）
- `xterm-256color` の terminfo を利用できる（不足する場合はコンテナ側で追加インストールしてよい）

## 判断材料/トレードオフ（Decision / Trade-offs） (任意)
- 論点: `TERM/COLORTERM` を「入口で注入」するか「コンテナ側で恒久化」するか
  - 選択肢A: 入口（`docker compose exec -e ...` 等）で毎回注入
    - Pros: 対話セッションに限定でき、副作用を局所化できる
    - Cons: 入口が増えると漏れやすい（`docker exec` 直叩き等）
  - 選択肢B: コンテナ側（Dockerfile/起動時設定）で恒久化
    - Pros: どの入口でも安定しやすく、運用上の付け忘れがない
    - Cons: 非対話コマンドでも env が立つ（副作用の可能性）
  - 決定: 選択肢B（コンテナ側で恒久化）を採用する
  - 理由: 本タスクは「色数が少ない問題の解消」をまず達成することが目的で、運用上の漏れを避けることを優先するため

## リスク/懸念（Risks） (任意)
- R-001: `COLORTERM=truecolor` を恒久化すると、非対話ログでも色有効と誤認するツールが出る可能性（影響: 低〜中 / 対応: 設計で「`COLORTERM` は必要なら対話時のみ」などのガードを検討する）
- R-002: `TERM=xterm-256color` により一部ツールのキー入力/描画が変わる可能性（影響: 低 / 対応: `tput colors` と基本操作の確認、必要なら `TERM` の適用条件を調整）

## 受け入れ条件（観測可能な振る舞い） (必須)
- AC-001:
  - Actor/Role: 開発者
  - Given: このリポジトリの Docker イメージを最新化してコンテナを起動できる
  - When: コンテナ内で `TERM/COLORTERM` と色数を確認する
  - Then: `docker compose exec` で `TERM=xterm-256color` / `COLORTERM=truecolor` となり、`tput colors` が `256` を返す
  - 観測点（UI/HTTP/DB/Log など）: `docker compose exec ... /bin/zsh -lc 'echo $TERM; echo $COLORTERM; tput colors'` の出力
- AC-002:
  - Actor/Role: 開発者
  - Given: このリポジトリの Docker イメージを最新化してコンテナを起動できる
  - When: `docker exec -it` でコンテナに入り `TERM/COLORTERM` と色数を確認する
  - Then: `TERM=xterm-256color` / `COLORTERM=truecolor` となり、`tput colors` が `256` を返す
  - 観測点（UI/HTTP/DB/Log など）: `docker exec -it ... /bin/zsh -lc 'echo $TERM; echo $COLORTERM; tput colors'` の出力
- AC-003:
  - Actor/Role: 開発者
  - Given: `./host/sandbox shell` または `./host/sandbox codex` を利用できる
  - When: その経路でコンテナ内に入り、Codex CLI を起動する
  - Then: 低色数フォールバック由来の表示崩れが解消し、視認性が改善している
  - 観測点（UI/HTTP/DB/Log など）: 目視（TUI の配色が極端に変化しない）、および `tput colors` の値
- AC-004:
  - Actor/Role: 開発者/CI
  - Given: テストを実行できる
  - When: `bash tests/sandbox_cli.test.sh`（必要なら追加のテスト）を実行する
  - Then: 成功する（退行がない）
  - 観測点（UI/HTTP/DB/Log など）: テスト結果（exit code / ログ）

### 入力→出力例 (任意)
- EX-001:
  - Input: `docker compose exec ... tput colors`
  - Output: `256`
- EX-002:
  - Input: `docker compose exec ... echo $TERM`
  - Output: `xterm-256color`

## 例外・エッジケース（仕様として固定） (必須)
- EC-001:
  - 条件: `xterm-256color` の terminfo がコンテナに存在しない
  - 期待: `tput colors` が失敗せず `256` を返せるように、必要なパッケージをインストールして解消する
  - 観測点（UI/HTTP/DB/Log など）: `infocmp xterm-256color` の成功、`tput colors=256`
- EC-002:
  - 条件: 利用者が意図的に `TERM` を別値で上書きしている（または tmux 等で `TERM=screen*`）
  - 期待: “少なくとも色数問題を起こさない”ことを優先し、必要なら適用条件/案内を `design.md` に明記する
  - 観測点: `tput colors` / 目視

## 用語（ドメイン語彙） (必須)
- TERM-001: `TERM` = 端末種別を示す環境変数（terminfo のエントリ選択に使われ、色数等の能力検出に影響する）
- TERM-002: `COLORTERM` = TrueColor 等の追加能力を示す慣習的な環境変数（TUI/CLI が参照することがある）
- TERM-003: terminfo = 端末能力データベース（`tput`/`infocmp`/`tic` が利用）
- TERM-004: 256 色 = `tput colors` が `256` を返す状態（8色/16色フォールバックより高精細）

## 未確定事項（TBD / 要確認） (必須)
- Q-001（解消済み / 2026-02-26 ユーザー回答: 1 常時設定）:
  - 質問: `COLORTERM=truecolor` を “常時” 設定するか、“対話セッションのみ” に限定するか？
  - 決定: A（常時設定）
  - 影響範囲: AC-001/002, R-001, 設計・テスト方針
- Q-002（解消済み / 2026-02-26 ユーザー回答: 2 含める）:
  - 質問: “保証対象の入口”はどこまで含めるか？（`docker exec -it` 直叩きも含むか）
  - 決定: B（`docker exec -it` も含める）
  - 影響範囲: AC-002, 設計・検証コマンド

## 完了条件（Definition of Done） (必須)
- すべてのAC/ECが満たされる
- 未確定事項が解消される（残す場合は「残す理由」と「合意」を明記）
- MUST NOT / OUT OF SCOPE を破っていない（追加機能を入れていない）

## 省略/例外メモ (必須)
- 該当なし
