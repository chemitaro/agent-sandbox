---
title: "SBX-CODEX-AUTO-BOOTSTRAP: 手動受け入れ手順"
status: "draft"
created: "2026-01-25"
---

# 手動受け入れ手順（proxyテストで観測できない部分）

この手順書は、`tests/` の proxy 観測では確認できない「実際に skills が認識される」ことを、人間が再現できる形で確認するためのものです。

## 前提
- 対象プロジェクトがコンテナにマウントされている（例: `/srv/mount/taikyohiyou_project`）
- 対象プロジェクトに repo-local skills がある（例: `.codex/skills/**/SKILL.md`）

```bash
# コンテナ内で実行（sandbox shell で入ってから）
cd /srv/mount/taikyohiyou_project
find .codex/skills -name SKILL.md
```

期待: `SKILL.md` が 1件以上ヒットする。

## 1. 初回（未Trust）→ bootstrap で起動され、Trust 導線が成立する

### 1-1. “未Trust” の確認
既に Trust 済みだと bootstrap にならないため、まず Trust 状態を確認します。

```bash
# コンテナ内で実行
cat ~/.codex/config.toml | sed -n '1,120p'
```

観測点:
- `[projects."/srv/mount/taikyohiyou_project"]`（または同等）が無ければ “未Trust” と判断できる。
- すでにある場合は、別の未Trustな worktree を使うか、テスト用に別パスへ worktree を作って試す。

### 1-2. `sandbox codex` を実行（ホスト側）
ホスト側の対象 repo ディレクトリで実行します。

```bash
cd <ホスト側の taikyohiyou_project のパス>
sandbox codex --workdir .
```

期待（正しい状態）:
- Codex が bootstrap モードで起動する（このとき approval/sandbox が最大権限ではない）。
- 起動直後に Trust の案内（trust onboarding / `/approvals` / `/permissions` など）が可能な状態になっている。
- `host/sandbox` が stderr に「Trust して再実行」案内を出す（実装後）。

失敗（誤った状態）:
- Trust の案内が一切出ず、`~/.codex/config.toml` にもプロジェクトが追加されない。

### 1-3. Codex 内で Trust を実行
Codex の UI に従って Trust を実行します（環境により導線は異なります）。

観測点（いずれかが成立すればOK）:
- 起動直後に “このディレクトリを trust するか” のプロンプトが出る → trust を選ぶ
- もしくは Codex 内で `/approvals` または `/permissions` を開き、Trust を許可する

### 1-4. Trust が永続化されたことを確認
Codex を一旦終了して、コンテナ内で config を確認します。

```bash
cat ~/.codex/config.toml | sed -n '1,200p'
```

期待:
- `[projects."/srv/mount/taikyohiyou_project"]`（または同等）が追加され、`trust_level = "trusted"` になっている。

## 2. 2回目以降（Trust済み）→ YOLO で起動され、skills が認識される

### 2-1. `sandbox codex` を再実行

```bash
cd <ホスト側の taikyohiyou_project のパス>
sandbox codex --workdir .
```

期待（正しい状態）:
- YOLO 相当（最大権限）で起動する（approval prompt が出ない / sandbox 制限が無い、等）。
- repo-local skills が認識される。

skills の観測（推奨）:
- Codex のセッション開始時に “skills 一覧” が表示される/参照できる場合は、`.codex/skills` にある skill 名が含まれること。
- あるいは Codex に対して「このプロジェクトの skills 名を列挙して」と質問し、repo-local skills（例: `spec-driven-tdd-workflow`）が回答に含まれること。

失敗（誤った状態）:
- YOLO で起動しているのに skills が一切認識されない（= Trust 判定/`--cd`/起動ディレクトリがズレている可能性）。

## 3. 非Gitディレクトリ（任意）
`sandbox codex` を非Gitディレクトリで起動し、落ちないことを確認します。

```bash
mkdir -p /srv/mount/_tmp_non_git
cd /srv/mount/_tmp_non_git

# ホスト側で
cd <ホスト側の対応パス>/_tmp_non_git
sandbox codex --workdir .
```

期待（正しい状態）:
- Codex が起動できる。
- 既定モード（YOLO/boot）は requirement.md Q-001 の決定どおり。

## 省略/例外メモ
- Trust 状態の “リセット” は運用破壊の恐れがあるため、ここでは手順化しない（必要なら別途相談）。
