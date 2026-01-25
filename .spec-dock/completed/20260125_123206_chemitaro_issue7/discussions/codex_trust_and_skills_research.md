# Codex trust / project root / skills 認識（調査メモ）

このドキュメントは、本タスク（`@.spec-dock/current/requirement.md`）の背景理解のための調査メモです。  
最終的な仕様（To-Be）は `requirement.md` / `design.md` を正とします。

## 目的
- コンテナ内で Codex CLI が repo-scope skills（`<worktree>/.codex/skills`）を認識しない事象の根本原因を、概念レベルで整理する。
- “設定ファイル機械編集”に頼らず、運用・設計で安定させる方向性を検討する。

## 観測（現場の事実）
- `projects`（trust 設定）に **`/srv/mount/<repo_or_worktree>`** を追加すると skills が認識される。
- しかし **`/srv/mount` のみ**を trusted にしても、`/srv/mount/<repo_or_worktree>` で起動した Codex が skills を認識しないケースがある。
- `agent-sandbox` は Git worktree を想定しており、mount-root が repo root より上位（LCA）になることで、コンテナ側の repo/worktree が `/srv/mount/<...>` 配下に配置されやすい。

## 仮説（原因の整理）
- Codex は trust を「親ディレクトリ trusted を子に継承」する prefix 判定ではなく、**限定的なキー（dir/project_root/repo_root）での一致**で判定している可能性が高い。
- trust が乗らない場合、repo の `.codex` が “disabled（untrusted）” 扱いになり、layer stack から `.codex/skills` が探索対象として落ちる。

## 要件への含意
- “worktree を包含する mount-root（LCA）” を維持したまま `projects` 増殖を避けるには、Codex が trust 判定に使う **project root を `/srv/mount` に寄せる**（= trust を 1 点に集約する）設計が有力。
- ただし `/srv/mount` 配下全体が trust 対象になり得るため、運用前提（`/srv/mount` を信頼済みワークスペース専用にする/例外を明示 untrusted にする等）が必要。

## 参考情報（外部）
- GPT-5.2 Pro（Web）による OSS ソース参照レポート（3本、2026-01-24）
  - 要点: trust は prefix 継承ではなく “キー一致” に近い、skills は layer stack 由来、`project_root_markers` を環境側で定義すると安定化し得る、など

