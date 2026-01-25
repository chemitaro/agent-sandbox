---
種別: ヒアリング（質問・選択肢・推奨）
機能ID: "FEAT-SANDBOX-CODEX-RUNTIME-TRUST-001"
作成者: "Codex CLI"
最終更新: "2026-01-25"
---

# FEAT-SANDBOX-CODEX-RUNTIME-TRUST-001 — ヒアリング事項（Q-001〜）

この機能は「`sandbox codex` は最大権限で動かしたい（`-a never -s danger-full-access`）が、その設定のせいで trust 画面が出ず skills が無効化される」問題を、**永続 config を触らず**に `-c/--config` で **実行時だけ trust を注入して解決**する方針です。

ここで決めるのは主に「どのディレクトリを trust した扱いにするか（スコープ）」と「非 git をどう扱うか」です。

## 回答（2026-01-25）
- Q-001: C
- Q-002: B
- Q-003: A
- Q-004: No（`sandbox shell` はプレーン codex 運用）

---

## Q-001: git/worktree の `trust_dir` をどれにするか？

### 背景（なぜ悩むか）
- git worktree がある場合、`git rev-parse --show-toplevel` は **現在の worktree ルート**を返します。
- 一方で、Codex 本体は trust 判定の fallback として **repo root（worktree 群を束ねる単位）**を参照する実装があります（`--git-common-dir` 起点の root）。
- どちらを trust しても、最終的に「この起動で skills が有効化される」目的は達成できますが、**trust の爆発半径**と **将来の安定性**が変わります。

### 選択肢

#### A) worktree root を trust
- 取得: `git -C <dir> rev-parse --show-toplevel`
- Pros:
  - trust の範囲が最も狭い（基本、その worktree だけを trust）
  - “worktree ごとに独立して扱いたい” 直感に合う
- Cons:
  - 同一 repo の別 worktree に移動した場合、その worktree では再度 trust 注入が必要（ただし runtime 注入なので実害は小さい）

#### B) root git project for trust（common-dir の親）を trust
- 取得: `git -C <dir> rev-parse --git-common-dir` の親ディレクトリ
- Pros:
  - Codex が worktree 群をまとめて trust 判定する単位に寄せられる（内部実装との整合が高い）
  - 同一 repo の worktree を横断する作業（比較・レビュー）で “その場でハマりにくい”
- Cons:
  - trust の範囲が広がる（同一 repo の他 worktree も trust され得る）

#### C) A と B の両方を trust（runtime 注入で 2 エントリ）
- Pros:
  - project_root/repo_root のどちらで trust 判定されても成立し、事故が最も少ない
  - 将来 Codex 側の “どのキーで trust を見るか” が変わっても壊れにくい
- Cons:
  - `projects` の注入エントリが 2 つになる（ただし実行時のみ）

### 推奨
- 推奨: **C**
  - このツールは「永続設定を増殖させない」のが狙いなので、runtime 内で 2 エントリ増えることは実害がほぼありません。
  - 逆に、ここで事故ると skills が使えず実用性が落ちるため「壊れにくさ」を優先します。

### 確認（回答）
- Q-001 は **A / B / C** のどれで進めますか？

---

## Q-002: 非 git ディレクトリ（`.git` なし）の `trust_dir` をどう扱うか？

### 背景（なぜ悩むか）
- git でない場所でも `sandbox codex` を使う要件があります。
- ただし git でない場合は「repo root を特定できない」ので、trust 注入の対象を別ルールで決める必要があります。
- trust は `.codex`（skills/rules/config）を有効化するために使われます。つまり、**そのディレクトリ配下に `.codex` が無いなら trust 注入してもしなくても実質変わりません**。

### 選択肢

#### A) trust 注入しない
- Pros:
  - trust の爆発半径を最小化できる
  - 期待しない `.codex` が有効化されない
- Cons:
  - 非 git でも `.codex/skills` を使いたいケースでは詰む（skills が有効化されない）

#### B) 常にカレントディレクトリ（effective `--cd`）を trust して注入する
- Pros:
  - 非 git のプロジェクトでも `.codex` を置けば同様に運用できる
  - 迷いがなく、実装も単純
- Cons:
  - “`.codex` があると実行時に自動で有効化される” ので、意図せず `.codex` を拾ってしまうリスクは増える

#### C) `.codex` がある場合だけ B を行う（無ければ注入しない）
- Pros:
  - `.codex` が必要なときだけ trust を注入できる（無駄撃ちを避けられる）
  - “意図しない `.codex` 有効化” のリスクを下げられる
- Cons:
  - `.codex` 判定ロジック（どこを見るか）を決める必要がある

### 推奨
- 推奨: **C**
  - 「skills が必要な時だけ trust」という挙動が最も自然で、運用事故が少ないためです。

### 追加で決めたい（C を選ぶ場合）
- `.codex` の判定範囲:
  - C-1: effective dir 直下のみ（`<dir>/.codex`）
  - C-2: effective dir から親へ辿って最初に見つかった `.codex`（ただし mount-root まで）
  - 推奨: **C-1**（まずは単純に。必要が出たら拡張）

### 確認（回答）
- Q-002 は **A / B / C** のどれで進めますか？（C の場合は C-1/C-2 も選択してください）

---

## Q-003: 自動 trust 注入を opt-out できるようにするか？

### 背景
- `sandbox codex` は “最大権限 + trust 自動注入” で動くため、意図としては「この環境では trust を UI 承認で守らない」設計になります。
- ただ、運用によっては「一時的に trust 注入を切りたい」場面もあり得ます。

### 選択肢
- A) 追加しない（`sandbox codex` は常に自動 trust）
- B) 追加する（例: `sandbox codex --no-auto-trust`）

### 推奨
- 推奨: **A**
  - スコープを増やさず最小変更で終えるため。
  - B が必要になったら後から追加しやすい（CLI の増分で対応可能）。

### 確認（回答）
- Q-003 は **A / B** のどちらで進めますか？

---

## 追加質問（要件外かもしれませんが重要）

### Q-004: `sandbox shell` 内で `codex` を直接起動する運用も “直したい” ですか？
- 今回の方針は `sandbox codex` に引数を足す設計です。
- そのため、`sandbox shell` →（コンテナ内）`codex ...` を手動で起動するケースは **同じ問題（trust 画面が出ない/skills が無効化される）**が再発します。
- もしここも MUST にしたいなら、別の打ち手が必要です（例: コンテナ内に `codex` ラッパースクリプトを置く / シェル rc で alias 化する、等）。

確認:
- Q-004: `sandbox shell` でも “直接 codex を起動して skills が使える” を要件に含めますか？（Yes/No）
