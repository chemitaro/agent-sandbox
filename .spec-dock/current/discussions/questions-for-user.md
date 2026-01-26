---
title: "SBX-CODEX-AUTO-BOOTSTRAP: ヒアリング（未確定事項）"
status: "draft"
created: "2026-01-25"
---

# ヒアリング（未確定事項）

この資料は、要件定義/設計の「未確定事項（TBD）」を解消するための質問集です。  
各問は「選択肢」と「推奨案（理由つき）」まで書いてあります。短く回答できるようにしてあります。

## 1) 非Gitディレクトリの既定モード（Q-001）
### 背景
- 非Gitでも `sandbox codex` を使う要件があります。
- 非Gitでは repo-local skills（`.codex/skills`）の期待が低い前提なら、Trust 確立を待たずに最大権限で起動しても問題になりにくい一方、Git必須チェックは回避が必要になり得ます（`--skip-git-repo-check`）。

### 選択肢
- **1A**: 非Gitは常に YOLO で起動（+ `--skip-git-repo-check` を付与）。Trust は判定/誘導しない。
- **1B**: 非Gitでも Trust 未確立なら bootstrap（Trust導線を優先）。

### 推奨案
- **推奨: 1A**
  - 理由: 非Gitで skills を強く期待しない運用が多く、利便性（最大権限デフォルト）を優先できるため。
  - 代償: 非Gitで `.codex/skills` を使いたい場合は、別途運用（`sandbox shell` で素の codex など）が必要。

---

## 2) `sandbox codex -- [codex args...]` の競合引数の扱い（Q-002）
### 背景
- `sandbox codex` は内部で bootstrap/yolo を選択します。
- ユーザーが `--yolo` / `--profile` / `--sandbox` / `--ask-for-approval` / `--config`（特に approval/sandbox をいじるもの）を渡すと、設計意図を壊し、未Trustでも YOLO 起動して “skills が出ない状態で詰む” 事故が起き得ます。

### 対象にしたい「競合引数」の例（案）
- `--yolo` / `--dangerously-bypass-approvals-and-sandbox`
- `--sandbox ...` / `-s ...`
- `--ask-for-approval ...` / `-a ...`
- `--profile ...` / `-p ...`
- `--config ...` / `-c ...`（※特に `approval_policy` / `sandbox_mode` を触るもの）

### 選択肢
- **2A**: 競合引数が渡されたらエラーにして終了（代替手段として `sandbox shell` で素の `codex` を案内）
- **2B**: 競合引数は許容し、sandbox 側の付与を最終（上書き）
- **2C**: 競合引数は許容し、ユーザー指定を優先（上書き）

### 推奨案
- **推奨: 2A**
  - 理由: 安定運用（“詰まない”）を最優先し、挙動の決定性を確保するため。
  - 代償: `sandbox codex` の自由度は落ちるが、逃げ道として `sandbox shell` がある。

---

## 3) YOLO の具体付与方法（Q-003）
### 背景
- 目的は「最大権限デフォルト」。
- 公式CLIには 1発で bypass する `--yolo` がある一方で、要件上は `approval_policy="never"` と `sandbox_mode="danger-full-access"` が明確に意図されています。

### 選択肢
- **3A**: `--yolo` を使う（bypass）
- **3B**: `--sandbox danger-full-access` + `--ask-for-approval never` を使う（明示）

### 推奨案
- **推奨: 3B**
  - 理由: 意図した「最大権限」を具体化でき、今後の挙動差分（bypass の範囲）を避けやすい。

---

# 回答形式（コピペ用）
例: `1A 2A 3B`
