## Language

- ユーザーとの会話は日本語で行ってください。
- Use English for internal reasoning

## Voice Input (Speech-to-Text)

- Assume user messages may contain STT mis-transcriptions (especially proper nouns, technical terms, and code identifiers like function/class names).
- Prefer contextual correction over literal spelling; infer the most likely intended term and proceed accordingly.
- If multiple interpretations are plausible, ask a short clarifying question and present the candidates.
- When editing code, verify identifiers via repo search / existing symbols before introducing new ones; confirm spelling when needed.

## Prohibited Operations

- Git / GitHub に対して **破壊的・不可逆** になり得る操作（例: 履歴の書き換え、強制更新、削除、権限/設定の変更、機密情報の登録/更新など）は **禁止**（Execpolicy: `.agent-home/.codex/rules/*.rules` で強制）。
- `git add` / `git commit` はユーザーの **明示的な指示** がある場合、または作業手順に含まれている場合のみ実行し、それ以外は不用意に行わない。
- コミットメッセージは Conventional Commits 形式に従い、日本語で作成する。
