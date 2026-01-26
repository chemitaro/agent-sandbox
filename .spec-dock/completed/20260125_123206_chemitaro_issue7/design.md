---
種別: 設計書
機能ID: "FEAT-CODEX-TRUST-001"
機能名: "コンテナ内Codexのスキル認識を安定化（複数worktree並行運用）"
関連Issue: ["N/A"]
状態: "approved"
作成者: "Codex CLI"
最終更新: "2026-01-24"
依存: ["requirement.md"]
---

# FEAT-CODEX-TRUST-001 コンテナ内Codexのスキル認識を安定化（複数worktree並行運用） — 設計（HOW）

## 目的・制約（要件から転記・圧縮） (必須)
- 目的:
  - `sandbox` 経由で起動した Codex CLI が、各 worktree の `.codex/skills` を安定して認識できるようにする（`@.spec-dock/current/requirement.md`）。
  - trust が必要な場合は、Codex の標準フロー（信頼の促し→ユーザー承認）で到達できる状態にする。
- MUST:
  - 単一コンテナ内で複数 worktree を並行運用しても、どの worktree でも skills を使える（AC-001/002/004）。
  - `sandbox shell` / `sandbox codex` の導線で再現する問題を解消する（AC-001/002/004）。
  - `sandbox` 自身は Codex 設定（`$CODEX_HOME/config.toml`）を直接編集しない（AC-003）。
- MUST NOT:
  - 外部ツールが `config.toml` を機械編集して `[projects]` を追記しない（MUST NOT）。
  - `--config` 等の runtime overrides を外部から注入しない（MUST NOT）。
  - `/etc/codex/config.toml` 等の system config をこのツールが導入して挙動を固定しない（MUST NOT）。
- 非交渉制約:
  - `sandbox` CLI 互換を維持（既存の使い方を壊さない）。
  - テストは実 Docker に依存せず、既存の stubs/helpers で determinism を保つ。
- 前提:
  - trust 促しでのユーザー手動承認は許容（Q-003）。

---

## 既存実装/規約の調査結果（As-Is / 95%理解） (必須)
### リポジトリ側（sandbox）
- `host/sandbox`
  - `sandbox shell`: `docker compose exec -w <container_workdir> agent-sandbox /bin/zsh`
  - `sandbox codex`: `docker compose exec -w <container_workdir> agent-sandbox /bin/zsh -lc 'codex resume ...; exec /bin/zsh'`
  - 現状、`config.toml`（`$CODEX_HOME/config.toml`）を作成・編集するロジックは存在しない（検索で確認）。
- `docker-compose.yml`
  - ホスト側 `.agent-home/.codex` をコンテナ `/home/node/.codex` にマウントしている（Codex が自分で設定を永続化できる前提）。
  - ホスト側の `SOURCE_PATH` をコンテナ `/srv/mount` にマウントしている。
- `tests/sandbox_cli.test.sh`
  - stubs により docker compose の実行コマンド列をログに残し、そこで振る舞いを観測している。
  - ただし `shell_trusts_git_repo_root_for_codex()` が「sandbox が `config.toml` を作って trust を追記する」前提になっており、AC-003 と矛盾している（更新が必要）。

### Codex 側（公式ドキュメント＋一次情報）
- Team Config の探索ルート（公式）:
  - `.codex/` は `$CWD/.codex/` → 親 → `$REPO_ROOT/.codex/` → `$CODEX_HOME` → `/etc/codex/` の順でロードされ得る（`https://developers.openai.com/codex/team-config`）。
- trust 設定（公式）:
  - `projects.<path>.trust_level` で、プロジェクト（worktree）を `"trusted"` / `"untrusted"` としてマークできる（`https://developers.openai.com/codex/config-reference`）。
  - 例（サンプル）: `[projects."/absolute/path/to/project"] trust_level = "trusted"  # or "untrusted"`（`https://developers.openai.com/codex/config-sample`）。
- trust の標準導線（公式）:
  - Codex は起動時に、設定に応じて「working directory を trust する」必要があり、onboarding prompt または `/approvals` を例として挙げている（`https://developers.openai.com/codex/security`）。
  - 上流 OSS では trust directory prompt の存在や、承認結果を `config.toml` に追記する挙動が報告されている（例: `https://github.com/openai/codex/issues/4940`, `https://github.com/openai/codex/issues/5160`）。
- 作業ディレクトリの指定（公式 CLI）:
  - `--cd, -C <path>` が「開始前に作業ディレクトリを設定する」グローバルフラグとして提供される（`https://developers.openai.com/codex/cli/reference`）。
  - グローバルフラグはサブコマンドの **後ろ**に置く（例: `codex exec --oss ...`）。同様に `codex resume --cd <path>` の形で指定できる（`https://developers.openai.com/codex/cli/reference`）。
  - `codex resume` は global flags を受け取り、`--last` は cwd にスコープし、必要なら `--all` で cwd 外を含められる（`https://developers.openai.com/codex/cli/reference`）。
- skills のロードタイミング（公式）:
  - Codex は startup 時に skills の名前/説明をロードし、追加・変更後は restart が必要（`https://developers.openai.com/codex/skills`）。
  - 参考メモ: `@.spec-dock/current/discussions/codex_trust_standard_operation.md`

---

## 設計方針（To-Be） (必須)
- 方針A（要件で合意済み）: repo/worktree 単位で trust を扱い、Codex 標準フロー（信頼の促し→ユーザー承認）で `projects.<path>.trust_level` が更新される前提で動かす。
- sandbox の責務:
  - Codex が trust 判定/skills 探索に使う **作業ディレクトリを確実に “今の worktree” に揃える**。
  - `config.toml` は **編集しない**（AC-003）。

---

## 判断材料/トレードオフ（Decision / Trade-offs） (任意)
- 論点: `sandbox codex` が Codex に渡す “作業ディレクトリ” をどこまで確実にできるか（skills/trust の安定性に直結）
  - A: docker compose exec の `-w` のみに依存（現状）
    - Pros: シンプル
    - Cons: `codex resume` が再開するセッション側で作業ディレクトリを保持する仕様の場合、skills/trust が “前回のディレクトリ” 基準になる可能性が残る
  - B: Codex の公式フラグ `--cd` を必ず指定して、Codex 側の作業ディレクトリを確実に container_workdir に合わせる（採用）
    - Pros: 公式インターフェースでディレクトリ基準を固定でき、skills/trust が安定する
    - Cons: `--cd` 非対応の古い Codex への互換性配慮が必要
- 決定: B

---

## インターフェース契約（ここで固定） (任意)
- IF-001: `host/sandbox::run_compose_exec_codex(container_workdir, container_name, compose_project_name, abs_mount_root, ...codex_args)`
  - 変更点:
    - `codex resume` 呼び出しに `--cd .` を **デフォルトで付与**し、Codex 側の作業ディレクトリを確実に container_workdir に揃える
    - ただし、ユーザーが `sandbox codex -- --cd <path>` / `sandbox codex -- --cd=<path>` または `sandbox codex -- -C <path>` / `sandbox codex -- -C<path>` を渡している場合は **重複回避のため sandbox 側は `--cd` を付与しない**（ユーザー指定を尊重）
    - `codex_args` は従来通り `sandbox codex -- [codex args...]` で渡されたものを後ろに連結する

---

## 変更計画（ファイルパス単位） (必須)
- 変更（Modify）:
  - `host/sandbox`
    - `run_compose_exec_codex`: `codex resume` 呼び出しに `--cd .` を追加し、Codex の作業ディレクトリを確実に container_workdir に揃える
    - `print_help` / `print_help_codex`: trust は Codex の標準フローに委ねる旨、`sandbox shell` で codex を起動する場合は `codex resume --cd .` を推奨する旨を短く補足（必要なら）
  - `tests/sandbox_cli.test.sh`
    - `shell_trusts_git_repo_root_for_codex`: 削除または否定テストへ変更（`.agent-home/.codex/config.toml` を作成しないこと = AC-003）
    - `codex_inner_runs_codex_resume_and_returns_to_zsh` / `codex_inner_without_double_dash_uses_default_args`: `--cd` が含まれることを観測点として追加
- 参照（Read only / context）:
  - `docker-compose.yml`: `.agent-home/.codex` の永続化（Codex 自身が trust を永続化する前提）
  - `@.spec-dock/current/requirement.md`: AC/EC/MUST NOT の根拠

---

## マッピング（要件 → 設計） (必須)
- AC-001 → `sandbox shell` は `-w` で worktree に入る。Codex のセッション再開時にディレクトリぶれが疑われる場合は `codex resume --cd .` を推奨（ヘルプ/手順で明記）
- AC-002 → `--cd` により trust 判定の基準ディレクトリを worktree に揃え、Codex 標準フローで trust 登録 → skills 認識へ到達
- AC-003 → `sandbox` は `config.toml` を直接編集しない（テストで担保）
- AC-004 → AC-002 と同様（新規 worktree でも trust 導線で到達）
- EC-001 → `/srv/mount` 一括 trust を行わず、混在を前提に worktree/repo 単位 trust を Codex に委ねる
- EC-002 → sandbox 側は `/srv/mount` を書き換えないため影響最小（必要ならエラーメッセージ整備）

---

## テスト戦略（最低限ここまで具体化） (任意)
### 観測の扱い（重要）
- 自動テストでは、実 Codex を起動して “skills が認識された” を直接観測できない（本 repo のテスト方針: 実 Docker/Codex へ依存せず stubs/helpers で determinism を保つ）。
- そのため本タスクでは、**`--cd` 付与（作業ディレクトリ固定）を proxy の観測点**として採用し、加えて **手動確認手順**を残して受け入れを完結させる（レビュー指摘に対応）。

- 更新するテスト（Bash, 既存 stubs 使用）:
  - `tests/sandbox_cli.test.sh::codex_inner_runs_codex_resume_and_returns_to_zsh`
    - Then: docker compose exec のコマンド列に `--cd` が含まれる（例: `codex resume --cd .`）
  - `tests/sandbox_cli.test.sh::codex_inner_without_double_dash_uses_default_args`
    - Then: `--cd` を含む `codex resume` が実行される
  - `tests/sandbox_cli.test.sh`（新規または既存修正）
    - Then: `sandbox shell` / `sandbox codex` 実行後も `.agent-home/.codex/config.toml` を作成していない（AC-003）
- 実行コマンド:
  - `bash tests/sandbox_cli.test.sh`

### 手動確認（受け入れ手順）
- 前提: worktree 内に確認用の skill が存在する（例: `<worktree>/.codex/skills/**/SKILL.md`）。
- `sandbox codex` の場合:
  1) `sandbox codex` を起動する（`--cd` は sandbox が自動で付与する）
  2) trust 促しが出たら承認する（prompt / `/approvals`）
  3) skills は startup 時ロードのため、承認後に skills が見えない場合は **Codex を再起動**する（セッション終了→再実行）
  4) プロジェクト固有 skills（例: 既知の skill 名）が利用できることを確認する
- `sandbox shell` の場合:
  1) `sandbox shell` で目的の worktree に入り、`pwd` が `/srv/mount/<repo_or_worktree>` 配下であることを確認する
  2) Codex を起動する際は `codex resume --cd .` を推奨（resume による作業ディレクトリぶれを抑止する）
  3) trust 促しが出たら承認し、必要なら再起動して skills を確認する（上と同様）

---

## リスク/懸念（Risks） (任意)
- R-001: Codex バージョン差で `--cd` が存在しない場合（影響: 起動失敗）
  - 対応（採用）: 本設計は `--cd` が利用可能な Codex CLI を前提とし、必要ならヘルプに明記する（この repo は `package.json` で `@openai/codex` をグローバル導入対象に含めている）
- R-002: trust エントリの増殖（影響: config 肥大化）
  - 対応: 本タスクでは “Codex の正規挙動として増える” ことは許容。sandbox 側は workdir の正規化（realpath）を維持する。

---

## 未確定事項（TBD） (必須)
- 該当なし

---

## 省略/例外メモ (必須)
- 該当なし
