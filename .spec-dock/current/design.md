---
種別: 設計書
機能ID: "CHORE-TUI-COLOR-001"
機能名: "コンテナ内の色数（TERM/COLORTERM）を安定化して Codex CLI の表示崩れを解消"
関連Issue: ["N/A"]
状態: "draft"
作成者: "Codex CLI"
最終更新: "2026-02-26"
依存: ["requirement.md"]
---

# CHORE-TUI-COLOR-001 コンテナ内の色数（TERM/COLORTERM）を安定化して Codex CLI の表示崩れを解消 — 設計（HOW）

## 目的・制約（要件から転記・圧縮） (必須)
- 目的: コンテナ内で Codex CLI が低色数フォールバックせず、少なくとも 256 色以上前提で表示できる状態にする。
- MUST:
  - `TERM=xterm-256color`（`tput colors=256`）を恒久的に満たす
  - `COLORTERM=truecolor` を常時設定する
  - `docker compose exec` / `docker exec -it` の両方で成立させる
  - 退行防止テストを追加する
- MUST NOT:
  - Ghostty 側設定の変更を前提にしない
  - `TERM=xterm-ghostty` の完全一致を必須にしない
  - Codex CLI 本体のテーマ定義は変更しない
- 非交渉制約:
  - `./host/sandbox` の既存フローを壊さない
  - 既存テスト（少なくとも `bash tests/sandbox_cli.test.sh`）を壊さない
  - 秘匿情報（`.env`）をドキュメント/ログに残さない

---

## 既存実装/規約の調査結果（As-Is / 95%理解） (必須)
- 参照した規約/実装（根拠）:
  - `AGENTS.md`: 会話/作業規約
  - `docker-compose.yml`: `tty: true`/`stdin_open: true` 設定でも、現状は `TERM=xterm` になっていることを確認するため
  - `Dockerfile`: コンテナ内の既定環境変数/インストール済みパッケージの確認のため
  - `host/sandbox`: `docker compose exec` を入口としているため（入口補正ではなくコンテナ恒久化で直す前提でも、現状把握が必要）
- 観測した現状（事実）:
  - ホスト: `TERM=xterm-ghostty` / `COLORTERM=truecolor`
  - コンテナ（現状）:
    - `docker compose exec` で `TERM=xterm`, `COLORTERM=`（未設定）, `tput colors=8`
    - `docker exec -it` でも `TERM=xterm`, `COLORTERM=`（未設定）, `tput colors=8`
  - コンテナで `TERM=xterm-256color` + `COLORTERM=truecolor` を与えると `tput colors=256` になる（色数問題の解消に直結）
- 採用するパターン:
  - コンテナ作成時点の環境変数（image の `ENV`）で `TERM/COLORTERM` を恒久化する
  - 退行防止は「Dockerfile の内容検査」テストで担保する（このリポのテスト方針: 実 Docker を叩かない）
- 採用しない/変更しない（理由）:
  - `host/sandbox` で `docker compose exec -e ...` を付与する方法は採用しない（要件の決定: コンテナ側で恒久化 / `docker exec -it` 直叩きも含めるため）
  - Ghostty terminfo（`xterm-ghostty`）の注入はしない（完全一致は不要）
- 影響範囲:
  - 変更対象: `Dockerfile`, `tests/`（新規テスト追加）
  - 参照対象: `docker-compose.yml`, `host/sandbox`（挙動確認のみ。原則変更なし）

## 主要フロー（テキスト：AC単位で短く） (任意)
- Flow for AC-001/002:
  1) 開発者が `./host/sandbox up` でコンテナを作成/起動する
  2) `TERM/COLORTERM` がコンテナ作成時点で既定値として設定される
  3) 開発者が `docker compose exec` / `docker exec -it` で入ったシェルで `tput colors=256` を満たす
  4) Codex CLI が低色数フォールバックせずに描画でき、視認性が改善する

## 判断材料/トレードオフ（Decision / Trade-offs） (任意)
- `COLORTERM=truecolor` は常時設定（要件決定済み）
  - 副作用（非対話ログの色など）が問題化した場合のみ、別タスクで「対話時のみ」へ変更する

## インターフェース契約（ここで固定） (任意)
- IF-ENV-001: コンテナ作成時の既定環境変数
  - `TERM` は `xterm-256color`
  - `COLORTERM` は `truecolor`
  - 期待効果: `docker compose exec` / `docker exec -it` の両方で `tput colors=256` を満たす

## 変更計画（ファイルパス単位） (必須)
- 追加（Add）:
  - `tests/sandbox_term_env.test.sh`: Dockerfile の `TERM/COLORTERM` 恒久化を退行防止として検査する
- 変更（Modify）:
  - `Dockerfile`:
    - `ENV TERM=xterm-256color`
    - `ENV COLORTERM=truecolor`
    - `ncurses-term` をインストール対象に追加（`xterm-256color` terminfo を確実に持つため）
- 参照（Read only / context）:
  - `docker-compose.yml`: `tty: true` であっても `TERM` が `xterm` になる現状の確認（変更は原則不要）
  - `tests/sandbox_cli.test.sh`: 既存のテスト方針（Docker/Compose を stub する）に合わせるため

## マッピング（要件 → 設計） (必須)
- AC-001 → `Dockerfile`（`ENV TERM=...`, `ENV COLORTERM=...`）、手動確認コマンド（`docker compose exec ... tput colors`）
- AC-002 → `Dockerfile`（同上）、手動確認コマンド（`docker exec -it ... tput colors`）
- AC-003 → 手動確認（Codex CLI 起動 + 目視）
- AC-004 → `tests/sandbox_term_env.test.sh` + 既存 `tests/sandbox_cli.test.sh`
- EC-001 → `Dockerfile`（`ncurses-term` の追加）+ 手動確認（`infocmp xterm-256color`）
- 非交渉制約 → テスト実行（`bash tests/sandbox_cli.test.sh`）と変更範囲の最小化（host/sandbox は原則変更しない）

## テスト戦略（最低限ここまで具体化） (任意)
- 追加/更新するテスト:
  - Unit（ファイル検査）:
    - `tests/sandbox_term_env.test.sh`
      - `Dockerfile` に `ENV TERM=xterm-256color` が存在する
      - `Dockerfile` に `ENV COLORTERM=truecolor` が存在する
  - 既存:
    - `bash tests/sandbox_cli.test.sh`（入口の退行防止）
- 手動受け入れ（AC-001/002/003）:
  - `./host/sandbox down || true && ./host/sandbox up`
  - `docker compose exec agent-sandbox /bin/zsh -lc 'echo TERM=$TERM; echo COLORTERM=$COLORTERM; tput colors'`
  - `docker exec -it <container> /bin/zsh -lc 'echo TERM=$TERM; echo COLORTERM=$COLORTERM; tput colors'`
  - コンテナ内で Codex CLI を起動し、配色崩れが解消していることを目視確認
- 実行コマンド:
  - `bash tests/sandbox_term_env.test.sh`
  - `bash tests/sandbox_cli.test.sh`

## リスク/懸念（Risks） (任意)
- R-001: `COLORTERM=truecolor` 常時設定により、非対話ログでも色有効と誤認するツールが出る可能性
  - 対応: 問題が顕在化した場合は「対話時のみ」へ寄せる（別タスク。今回のスコープ外）
- R-002: `TERM=xterm-256color` 固定が、一部環境で実 terminal 能力と不一致になる可能性
  - 対応: 本タスクは “この sandbox 環境” の対話利用を主対象とし、問題が出た場合は適用条件（例: `-t 1` のときのみ等）を設計変更する

## 未確定事項（TBD） (必須)
- 該当なし（requirement.md の Q-001/Q-002 は解消済み）

## 省略/例外メモ (必須)
- UML 図や詳細なデータ設計は不要（環境変数の恒久化が対象のため）
