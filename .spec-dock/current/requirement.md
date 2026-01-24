---
種別: 要件定義書
機能ID: "FEAT-CODEX-TRUST-001"
機能名: "コンテナ内Codexのスキル認識を安定化（複数worktree並行運用）"
関連Issue: ["N/A"]
状態: "draft"
作成者: "Codex CLI"
最終更新: "2026-01-24"
---

# FEAT-CODEX-TRUST-001 コンテナ内Codexのスキル認識を安定化（複数worktree並行運用） — 要件定義（WHAT / WHY）

## 目的（ユーザーに見える成果 / To-Be） (必須)
- `sandbox`（このリポジトリのコンテナ環境）経由で Codex CLI を起動した場合でも、**各 worktree の `.codex/skills` が安定して認識**される。
- 同一コンテナ内で **複数 Git worktree を並行運用**（作成/編集/比較/レビュー）しても、skills 利用のために “手で設定ファイルを編集する” 必要がない。
- trust 設定（`projects`）が必要になって増える場合でも、それは **Codex の標準フロー（信頼の促し→ユーザー承認）で更新される**（外部ツールが機械的に編集しない）。

## 背景・現状（As-Is / 調査メモ） (必須)
- 現状の挙動（事実）:
  - このリポジトリの `sandbox` CLI は Docker Compose を起動し、ホストの作業ディレクトリをコンテナ内 `/srv/mount` にマウントして作業する（`docker-compose.yml`, `host/sandbox`）。
  - Git worktree を想定した mount-root 自動判定（worktree 群を包含する LCA を mount-root にする）により、コンテナ側では repo/worktree が `/srv/mount/<repo_or_worktree>` のような**サブディレクトリ**として配置されることがある。
  - この状態でコンテナ内の Codex CLI を起動すると、プロジェクト固有の skills（`<worktree>/.codex/skills`）が認識されず、system skills しか使えないケースがある。
  - 一方で、Codex の `projects`（trust 設定）に **`/srv/mount/<repo_or_worktree>` を追加**すると skills が認識される（= trust 増殖が起きる）。
- 現状の課題（困っていること）:
  - コンテナ内で Codex を使うと、プロジェクト固有のワークフロー（skills）が使えず、生産性が落ちる。
  - 対症療法として `projects` を repo/worktree ごとに追加すると、設定ファイルが増殖し、管理不能・意図しない trust 境界拡大・将来の仕様変更で破綻する懸念がある。
- 再現手順（最小で）:
  1) 複数 worktree が存在するリポジトリで `sandbox shell`（または `sandbox codex`）を起動する
  2) コンテナ内で repo/worktree が `/srv/mount/<...>` 配下にある状態で Codex を起動する
  3) skills が system のみで、プロジェクト固有（`<worktree>/.codex/skills`）が見えないことを確認する
- 観測点（どこを見て確認するか）:
  - Codex 起動時/実行時に、プロジェクト固有 skills が認識されていること（表示/UI/ログ/挙動のいずれか、実装で観測方法を固定する）
  - `sandbox` 自身が Codex 設定（`$CODEX_HOME/config.toml` 等）を直接編集していないこと
  - `sandbox` の既存 CLI が破綻していないこと（`bash tests/sandbox_cli.test.sh` が通る）
- 実際の観測結果（貼れる範囲で）:
  - repo-scope skills が見えない状態が発生し、`projects` に `/srv/mount/<repo_or_worktree>` を追加すると改善する（ただし増殖が問題）。
- 情報源（ヒアリング/調査の根拠）:
  - ヒアリング: 本スレッドのディスカッション（単一コンテナ内で複数 worktree を並行運用する要件、設定増殖を避けたい、など）
  - 調査メモ: `@.spec-dock/current/discussions/codex_trust_and_skills_research.md`
  - 追加資料: `@.spec-dock/current/discussions/qa-with-gpt52pro.md`（外部調査のメモ/参照用）
  - コード:
    - `host/sandbox`（mount-root/workdir の決定、コンテナ workdir 変換、起動導線）
    - `docker-compose.yml`（`/srv/mount` への bind mount、`/home/node/.codex` の永続化）

## 対象ユーザー / 利用シナリオ (任意)
- 主な利用者（ロール）:
  - `agent-sandbox` を使って、コンテナ内で Codex CLI を常用する開発者
- 代表的なシナリオ:
  - 1つのリポジトリで複数 worktree を作成し、同一コンテナ内で並行に実装/レビュー/比較を行う
  - worktree を追加・削除しながら継続運用する（= trust 設定を都度増やしたくない）

## スコープ（暴走防止のガードレール） (必須)
- MUST（必ずやる）:
  - 単一コンテナ内で複数 worktree を並行運用しても、どの worktree から起動してもプロジェクト固有 skills が利用できる状態にする
  - worktree の追加に伴い trust 登録が必要になっても、**Codex の標準フロー**（信頼の促し→ユーザー承認）で登録できる（“worktree ごとに手で config を編集”しない）
  - `sandbox shell` と `sandbox codex` の導線で再現する問題を解消する
- MUST NOT（絶対にやらない／追加しない）:
  - host 側ラッパー等が `~/.codex/config.toml`（または `.agent-home/.codex/config.toml`）を直接パースして機械編集し、`projects` を都度追記する方式を最終解にしない
  - 起動時の runtime overrides（`--config` 等）で trust/marker を外部から注入する方式（B-4）を最終解にしない
  - system config（例: `/etc/codex/config.toml`）を外部ツールが bake-in / mount して挙動を固定する方式を最終解にしない
  - `/` や `$HOME` 等の過度に広いパスを trust する前提にしない
- OUT OF SCOPE（今回やらない）:
  - Codex CLI 本体（openai/codex）への機能追加/パッチ送信
  - trust 境界モデルの抜本変更（例: wildcard/prefix trust を Codex 側に追加する）
  - skills の内容や運用ルール（SKILL.md の中身）の整理自体

## 非交渉制約（守るべき制約） (必須)
- `sandbox` の既存 CLI 互換（既存の使い方が壊れないこと）を維持する
- テストは determinism を維持し、可能な限り既存の stubs/helpers で担保する（実 Docker 実行に依存しない）
- trust 境界が広がる場合は、その意味と運用前提（“置き場所を分ける” 等）を明文化する

## 前提（Assumptions） (必須)
- `/srv/mount` はコンテナ内の “作業領域” として、このツールが制御できる（Dockerfile/docker-compose/entrypoint を変更可能）
- 各 worktree には `.codex/skills` を置ける（既に運用されている）
- Codex CLI が untrusted な project config folder（`.codex`）に対して、**信頼の促し→ユーザー承認**の標準フローを提供している
- `sandbox` 経由でも、Codex の trust 承認プロンプトをユーザーが操作できる（TTY/STDIN/STDOUT が遮断されない）

## 判断材料/トレードオフ（Decision / Trade-offs） (任意)
- 論点: 「worktree を包含する mount-root（LCA）」と「設定ファイルの手編集を不要にする」をどう両立するか
  - 方針A: repo/worktree 単位で trust を扱い、Codex の標準フロー（信頼の促し→ユーザー承認）で登録する（採用）
    - Pros: 外部ツールの機械編集に依存しない / Codex の正規導線に寄せられる / 混在（Q-001）と整合
    - Cons: trust エントリは必要に応じて増える（ただし許容）
  - 方針B: `/srv/mount` を trust 1点に集約する（system config 等で project root を寄せる必要がある想定）
    - Pros: trust 増殖を抑えられる可能性がある
    - Cons: 混在（Q-001）と衝突し得る / system config 導入（Q-002）が必要になりやすい
  - 方針C: runtime overrides（`--config` 等）で trust/marker を注入する
    - Pros: 永続設定の機械編集を避けられる
    - Cons: MUST NOT（外部注入）に反する
  - 採用: 方針A

## リスク/懸念（Risks） (任意)
- R-001: trust エントリの増殖/表記ゆれ重複（影響: config の肥大化 / 対応: `sandbox` 側で workdir の正規化を徹底し、Codex の標準フローに寄せる）
- R-002: Codex CLI の挙動/仕様変更（影響: trust/skills の扱いが変わる / 対応: 外部ツールの機械編集・外部注入を避け、観測点をテストで固定する）

## 受け入れ条件（観測可能な振る舞い） (必須)
- AC-001:
  - Actor/Role: 開発者
  - Given: `sandbox shell` でコンテナに入り、作業ディレクトリが `/srv/mount/<repo_or_worktree>` 配下になっている
  - When: その worktree で Codex CLI を起動する
  - Then: その worktree の `.codex/skills` が認識され、プロジェクト固有 skills を利用できる
  - 観測点（UI/Log など）: 実装で観測方法を固定する（例: skills 一覧の表示/ログ/専用サブコマンド等）
- AC-002:
  - Actor/Role: 開発者
  - Given: 同一コンテナ内に複数 worktree が存在する
  - When: いずれの worktree からでも Codex CLI を起動する
  - Then: trust が未登録の worktree でも、Codex の標準フロー（信頼の促し→ユーザー承認）により trust を登録でき、AC-001 の状態へ到達できる
  - 観測点: 実装で観測方法を固定する（例: trust 促しの表示、承認後に skills が見える、など）
- AC-003:
  - Actor/Role: 開発者
  - Given: `sandbox` を利用する（`sandbox shell` / `sandbox codex`）
  - When: `sandbox` 経由で Codex を起動する
  - Then: `sandbox` 自身は Codex の設定ファイル（`config.toml`）を直接編集しない（trust 更新は Codex の標準機構に委ねる）
  - 観測点: 実装で観測方法を固定する（例: テストでファイル書き換えを行っていないことを検証）
- AC-004:
  - Actor/Role: 開発者
  - Given: コンテナ内で新しい worktree を作成した（例: `git worktree add`）
  - When: 新しい worktree で Codex CLI を起動する
  - Then: 追加の手作業（設定ファイルの手編集）なしに、必要に応じて Codex の標準フロー（信頼の促し→ユーザー承認）で trust を登録でき、skills が認識される
  - 観測点: 実装で観測方法を固定する（例: trust 促しの表示、承認後に skills が見える、など）

### 入力→出力例 (任意)
- 該当なし（観測方法は設計フェーズで固定する）

## 例外・エッジケース（仕様として固定） (必須)
- EC-001:
  - 条件: `/srv/mount` に “trust したくない repo” が混在している
  - 期待: 本タスクでは扱いを設計で明文化する（例: 明示的に untrusted を指定できる/専用ワークスペース運用を必須とする、等）
  - 観測点: 設計で固定する
- EC-002:
  - 条件: `/srv/mount` 直下に必要なファイルを作成できない（権限/読み取り専用など）
  - 期待: `sandbox` は分かりやすいエラーメッセージで失敗し、回避策（設定/権限/起動方法）を示す
  - 観測点: `sandbox shell` / `sandbox codex` の stderr と exit code

## 用語（ドメイン語彙） (必須)
- TERM-001: worktree = Git の worktree 機能により作成される作業ディレクトリ
- TERM-002: mount-root（ホスト側） = `sandbox` がコンテナに bind mount するホストのディレクトリ
- TERM-003: workspace root（コンテナ側） = 常に `/srv/mount`（mount の着地点）
- TERM-004: project root（Codex） = Codex が `project_root_markers` に基づき判定するプロジェクト境界
- TERM-005: trust（Codex） = `projects.<path>.trust_level` による project config folder（`.codex`）の有効/無効

## 決定事項（合意済み） (任意)
- D-001: Q-001 = B（混在し得る）: `@.spec-dock/current/discussions/q001_srv_mount_trust_scope.md`
- D-002: Q-002 = C（system config は導入しない）: `@.spec-dock/current/discussions/q002_codex_system_config_delivery.md`
- D-003: Q-003 = B（trust 促しでの手動承認は許容）: `@.spec-dock/current/discussions/q003_codex_trust_prompt_allow.md`

## 未確定事項（TBD / 要確認） (必須)
- 該当なし

## 完了条件（Definition of Done） (必須)
- すべてのAC/ECが満たされる
- 未確定事項が解消される（残す場合は「残す理由」と「合意」を明記）
- MUST NOT / OUT OF SCOPE を破っていない（追加機能を入れていない）

## 省略/例外メモ (必須)
- 該当なし
