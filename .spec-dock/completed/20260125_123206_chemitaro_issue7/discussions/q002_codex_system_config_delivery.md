# Q-002: Codex の system config（例: `/etc/codex/config.toml`）導入はOKですか？

更新日: 2026-01-24  
関連: `@.spec-dock/current/requirement.md`（Q-002）

## 質問（回答してください）
コンテナ環境に **Codex の system config**（例: `/etc/codex/config.toml`）を導入してよいですか？

- 選択肢A: Dockerfile に bake-in する（イメージに含める）
- 選択肢B: docker-compose で read-only mount する（ホスト側ファイルを `/etc/codex/config.toml` に差し込む）
- 選択肢C: 導入しない（Codex の標準的な信頼登録/設定更新の仕組みに任せる）

## なぜこの質問が重要か（意図）
本件の狙いは「worktree が増えても trust 設定を増殖させない」ことです。そのために、

- `project_root_markers` を **環境側で定義**し（例: `.git` ではなく “workspace root marker”）
- `projects."/srv/mount" = trusted` の 1 点で成立させる

という方針が有力です。

ただし、`project_root_markers` は（少なくとも設計上）**project レイヤ（repo 内 `.codex/config.toml`）より前に効いている必要**があるため、ユーザー設定や system 設定として与えるのが筋になります。

つまり、**system config をどう配布するか**が、実装の安定性・運用性・将来の変更耐性を左右します。

## 選択肢の整理（Pros / Cons）

### A: Dockerfile bake-in
- Pros:
  - 動作が最も一貫する（環境差が出にくい）
  - “このツールを入れたら常に直る”に近い形にできる
- Cons / 注意:
  - 設定変更にイメージ再ビルドが必要（試行錯誤が重い）
  - ユーザーが任意に差し替えたい場合に柔軟性が低い

### B: compose read-only mount（推奨になりやすい）
- Pros:
  - 設定をホスト側で差し替えられる（検証・切り戻しが容易）
  - イメージを汚さずに運用可能（CI/CD への影響を抑えられる）
  - “公式の system config レイヤ” に寄せつつ、運用で柔軟
- Cons / 注意:
  - compose/ホスト側のファイル配置が前提になる（README/ヘルプの整備が必要）
  - mount されない場合のフォールバック設計が必要（エラー/警告/無効時の挙動）

## 回答欄（記入してください）
- 決定: **C（導入しない）**（ユーザー回答: 2026-01-24）
- 追加情報（ユーザー発言の要約）:
  - system config の bake-in / mount を含め、外部ツールが “設定を投稿・加工・統合” する方式は避けたい
  - Codex が標準機構で trust/設定を調整するのは許容（= Codex の正しい挙動として増えるのは OK）
  - 仕様変更で壊れやすい外部注入/統合は避けたい

## 追加確認（任意だがあると助かる）
“system config を入れる”方式の場合、どこまでやりたいですか？
- S1: trust/marker だけを system config に置き、その他は従来どおりユーザー設定に任せる（最小介入）
- S2: さらに `CODEX_HOME` の分離（host と container を別ホームに）も行い、パス増殖を構造的に防ぐ
