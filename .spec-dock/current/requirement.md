---
種別: 要件定義書
機能ID: "GC-001"
機能名: "未使用ファイルの棚卸しと削除"
関連Issue: ["TBD"]
状態: "draft"
作成者: "Codex"
最終更新: "2026-01-23"
---

# GC-001 未使用ファイルの棚卸しと削除 — 要件定義（WHAT / WHY）

## 目的（ユーザーに見える成果 / To-Be） (必須)
- 大幅な機能変更のマージ後に、現在使われていないファイルを特定・整理し、不要物を削除して保守コストと混乱を減らす。

## 背景・現状（As-Is / 調査メモ） (必須)
- 現状の挙動（事実）:
  - `host/sandbox` が CLI エントリで、SANDBOX_ROOT と .agent-home の作成や docker compose 実行を担う。 (`host/sandbox`:52-108,183-220)
  - `docker-compose.yml` は `agent-sandbox` サービスのビルド・ボリューム・環境変数を定義している。 (`docker-compose.yml`:1-58)
  - `Dockerfile` は `scripts/init-firewall.sh` / `scripts/docker-entrypoint.sh` / `scripts/slack-notify.js` / `scripts/tmux-*` をコピー・登録し、エントリポイントを `docker-entrypoint.sh` に設定している。 (`Dockerfile`:191-223)
  - `docker-compose.git-ro.yml` は「Git metadata は書き込み可能がデフォルト」とのコメント付きで `volumes: []` のみを持っていた（削除済み）。 (`docker-compose.git-ro.yml`:1-5)
  - `scripts/generate-git-ro-overrides.sh` は Git の read-only マウント用 override を生成するスクリプトとして存在していた（削除済み）。 (`scripts/generate-git-ro-overrides.sh`:1-108)
  - `product/` ディレクトリは空で、`.keep` のみが存在していた（削除済み）。 (`product/.keep`)
- 現状の課題（困っていること）:
  - 大幅な機能変更後に未使用ファイルが残っているはずだが、現時点で棚卸しが無く、削除判断ができない。
- 再現手順（最小で）:
  1) リポジトリを開く。
  2) 主要エントリ/構成ファイル（`host/sandbox`, `Dockerfile`, `docker-compose.yml` 等）とその参照関係を確認する。
- 観測点（どこを見て確認するか）:
  - CLI: `host/sandbox`
  - コンテナ定義: `Dockerfile`, `docker-compose.yml`
  - ヘルパー/ツール: `scripts/*`, `tests/*`, `Makefile`
  - 置き場/空ディレクトリ: `product/` など
- 実際の観測結果（貼れる範囲で）:
  - Input/Operation: `ls` / `rg` / `git log --graph --decorate --oneline` による構成確認
  - Output/State: `git log` 上の大幅な変更は PR #6 (merge commit: `317aefd`, feature commit: `5f32992`) に集約されている
- 情報源（ヒアリング/調査の根拠）:
  - ヒアリング: 「大幅な機能変更のブランチをマージ」「コードツールの位置づけが変化」「未使用ファイルが残っている」
  - Git 履歴: `Merge pull request #6 from chemitaro/issue5` (`317aefd`) / `feat(sandbox): sandbox codex サブコマンド...` (`5f32992`)
  - コード: `host/sandbox`, `Dockerfile`, `docker-compose.yml`, `scripts/generate-git-ro-overrides.sh`, `docker-compose.git-ro.yml`, `product/.keep`

## 対象ユーザー / 利用シナリオ (任意)
- 主な利用者（ロール）:
  - リポジトリのメンテナ/開発者
- 代表的なシナリオ:
  - 変更後の構成を見直し、不要ファイルを削除してスリム化したい。

## スコープ（暴走防止のガードレール） (必須)
- MUST（必ずやる）:
  - リポジトリ全体を対象に、未使用ファイル候補を根拠付きでリスト化する。
  - 参照が無いものについて用途を分析し、未使用かどうかを判断する。
  - 削除対象を確定し、不要ファイルを削除する。
  - 削除後の参照関係チェック（参照が残っていないこと）を行う。
  - `Makefile` は公開コマンドを `install` / `help` のみに整理し、不要な変数・情報を削除する。
- MUST NOT（絶対にやらない／追加しない）:
  - 使用中・依存中のファイルを根拠なしに削除しない。
  - 動作変更や機能追加など、削除以外の改修を行わない。
  - ユーザー固有データ（`.env`, `.agent-home` など）を削除しない。
- OUT OF SCOPE（今回やらない）:
  - リファクタリング、構造変更、依存関係の更新
  - 新規機能追加

## 非交渉制約（守るべき制約） (必須)
- 既存の CLI/コンテナ起動フローを壊さない。
- 参照元が不明確なファイルは削除しない（用途分析が終わるまで保留）。
- 禁止 Git 操作（`git add` / `git commit` / `git push` / `git merge`）は実行しない。
- `.agent-home` は検査対象外で必ず残す。
- `.env.example` は保持する（`sandbox.config.example` をリネーム）。
- `sandbox.config` は削除対象に含める。

## 前提（Assumptions） (必須)
- 静的な参照確認（`rg` など）で未使用判定の一次判定が可能である。
- 外部（CI/CD, ドキュメント外部リンクなど）でのみ参照されるファイルがある場合は事前に共有される。

## 判断材料/トレードオフ（Decision / Trade-offs） (任意)
- 論点: 未使用判定の厳格さ
  - 選択肢A: 参照が無ければ削除（高速）
  - 選択肢B: 参照が無い場合でも用途確認の上で削除（安全）
  - 決定: B
  - 理由: 外部参照や運用依存の可能性を安全に排除するため

## リスク/懸念（Risks） (任意)
- R-001: 外部参照（CI/運用/配布物）にしか登場しないファイルを誤って削除する
  - 影響: 実運用での手順破綻
  - 対応: 事前ヒアリング + 「保留」カテゴリの導入

## 受け入れ条件（観測可能な振る舞い） (必須)
- AC-001:
  - Actor/Role: メンテナ
  - Given: リポジトリ全体の構成が取得できる
  - When: 参照調査と棚卸しを実施する
  - Then: 未使用候補が「根拠付きリスト（参照有無/用途/判断）」として提示される
  - 観測点（UI/HTTP/DB/Log など）: `@.spec-dock/current/discussions/garbage-files.md` または作業報告
  - 権限/認可条件（ある場合）: なし
- AC-002:
  - Actor/Role: メンテナ
  - Given: 未使用候補リストが確定している
  - When: 削除作業を実施する
  - Then: 削除対象がリポジトリから除去され、参照検索で参照が残っていないことが確認できる
  - 観測点（UI/HTTP/DB/Log など）: `rg` 検索結果、変更ファイル一覧
  - 権限/認可条件（ある場合）: なし
- AC-003:
  - Actor/Role: メンテナ
  - Given: 削除後の状態
  - When: 最低限の動作確認/テストを実施する
  - Then: 既存の CLI/補助スクリプトの動作に影響が無いことが確認できる（または理由付きで未実施が記録される）
  - 観測点（UI/HTTP/DB/Log など）: テスト実行ログ / `report.md`
  - 権限/認可条件（ある場合）: なし

### 入力→出力例 (任意)
- EX-001:
  - Input: 候補ファイル `docker-compose.git-ro.yml`
  - Output: 参照なし・用途不明のため「保留」または「削除候補」扱い

## 例外・エッジケース（仕様として固定） (必須)
- EC-001:
  - 条件: 参照がコード内に見つからないが、運用手順や外部ドキュメントで利用されている
  - 期待: 削除せず保留し、利用元の確認を先に行う
  - 観測点（UI/HTTP/DB/Log など）: ヒアリング結果、`discussions/` 記録
- EC-002:
  - 条件: 空ディレクトリ（`.keep` のみ）
  - 期待: 役割が不明なら削除せず確認する
  - 観測点: `ls` / リポジトリの参照状況

## 用語（ドメイン語彙） (必須)
- TERM-001: 未使用ファイル = 参照元（コード/設定/テスト/ドキュメント/運用手順）から見て不要と判断できるファイル
- TERM-002: 棚卸し = ファイル単位での用途・参照・削除可否の整理

## 未確定事項（TBD / 要確認） (必須)
- 該当なし

## 完了条件（Definition of Done） (必須)
- すべてのAC/ECが満たされる
- 未確定事項が解消される（残す場合は「残す理由」と「合意」を明記）
- MUST NOT / OUT OF SCOPE を破っていない（追加機能を入れていない）

## 省略/例外メモ (必須)
- 該当なし
