---
種別: 手動受け入れ手順
機能ID: "FEAT-SANDBOX-CODEX-RUNTIME-TRUST-001"
対象AC: ["AC-002"]
作成者: "Codex CLI"
最終更新: "2026-01-25"
---

# 手動受け入れ手順（AC-002: repo-scope skills が認識される）

この手順は「`sandbox codex` が runtime trust 注入により、repo-scope skills（`.codex/skills`）を Codex に認識させられている」ことを **Codex TUI の `/skills`（スラッシュコマンド）で観測**します。

## 前提
- 対象ディレクトリが **git repo** である（worktree でも可）
- 対象ディレクトリ配下に `.codex/skills/**/SKILL.md` がある
- `sandbox codex` 実行によりコンテナが起動できる（Docker が利用可能）

## 準備（ホスト側）
1) 対象 repo の場所へ移動する
   - 例: `cd /path/to/repo`

2) repo-scope skills が存在することを確認する
   - 実行（repo 直下）:
     - `find .codex/skills -name SKILL.md`
   - 期待:
     - 1件以上ヒットする（例: `.codex/skills/<skill-name>/SKILL.md`）

## 実行
3) `sandbox codex` を起動する（通常運用）
   - 実行（repo 直下）:
     - `sandbox codex`
   - 期待:
     - tmux セッションが起動し、Codex TUI が表示される

   補足（トラブルシュート用。tmux を使わず起動したい場合）:
   - `SANDBOX_CODEX_NO_TMUX=1 sandbox codex`

## 観測（成功/失敗の判定）
4) Codex の入力欄に `/skills` と入力して Enter
   - 期待（成功）:
     - Skills の UI（一覧/検索/選択）が表示される
     - 手順2で確認した repo-scope skills が一覧に出る（例: `<skill-name>` が見つかる）

5) 失敗時の典型例（NG 判定）
   - `/skills` の一覧に repo-scope skills が出ない（system/user のみ、または空）
   - 起動直後またはどこかで、次のようなメッセージが表示される（trust 不足の兆候）:
     - `Add /srv/mount/... as a trusted project in /home/node/.codex/config.toml.`

## 記録（report.md）
6) 実施ログを `.spec-dock/current/report.md` に残す
   - 記録する内容（最低限）:
     - 実行ディレクトリ
     - 実行コマンド（`sandbox codex` / `SANDBOX_CODEX_NO_TMUX=1 sandbox codex`）
     - `/skills` で確認できた repo-scope skills の名前（1つ以上）
     - 成否（OK/NG）と補足（NG の場合は画面メッセージ）

