# 調査: Codex でプロジェクトを trust（trusted 登録）する標準操作 / trust 後の skills 反映（再起動要否）

更新日: 2026-01-24  
関連: `@.spec-dock/current/design.md`（As-Is / To-Be 前提）, `@.spec-dock/current/requirement.md`（AC-002/003/004）

## 調査目的
- 「Codex でこのプロジェクトを信頼（trusted 登録）する標準の操作」を一次情報ベースで特定する
- trust 承認後、repo/worktree の `.codex/skills` が反映されるまでに **Codex の再起動が必要か**を一次情報ベースで整理する

## 事実（公式ドキュメント）
### trust（永続設定）
- `config.toml` の `projects.<path>.trust_level` で `"trusted"` / `"untrusted"` を設定できる
  - `projects` の例: `https://developers.openai.com/codex/config-reference`
  - サンプル（`[projects."/absolute/path/to/project"] trust_level = "trusted"`）: `https://developers.openai.com/codex/config-sample`

### trust（標準導線）
- Codex は環境/設定によって **working directory を明示的に trust するまで read-only で起動する**ことがあり、例として **onboarding prompt または `/approvals`** が挙げられている
  - `https://developers.openai.com/codex/security`

### skills（ロードと反映タイミング）
- Codex は **startup 時に skills の名前/説明をロード**する
- skill の追加/変更（インストールや無効化設定など）を反映するには **Codex の restart が必要**と明記されている
  - `https://developers.openai.com/codex/skills`

## 事実（上流の挙動根拠: openai/codex）
- trust directory prompt が表示される（ユーザーが選択できる）という報告がある
  - 例: `https://github.com/openai/codex/issues/4940`
- Codex が `config.toml` を実行時に書き換え（`[projects]` に trust を追加）する挙動が報告されている
  - 例: `https://github.com/openai/codex/issues/5160`

## 結論（本タスクで採用する前提）
- trust 登録（`projects.<path>.trust_level` の更新）は、外部ツールの機械編集ではなく **Codex の標準導線（prompt/承認）**に委ねる（AC-003 と整合）。
- skills は startup 時ロードのため、**trust 承認後に repo/worktree skills が見えない場合は Codex を再起動（= セッションを終了して再実行）する**のが仕様に沿う運用。
