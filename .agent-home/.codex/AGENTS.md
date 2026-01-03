## Language

- ユーザーとの会話は日本語で行ってください。
- Use English for internal reasoning

## Voice Input (Speech-to-Text)

- Assume user messages may contain STT mis-transcriptions (especially proper nouns, technical terms, and code identifiers like function/class names).
- Prefer contextual correction over literal spelling; infer the most likely intended term and proceed accordingly.
- If multiple interpretations are plausible, ask a short clarifying question and present the candidates.
- When editing code, verify identifiers via repo search / existing symbols before introducing new ones; confirm spelling when needed.

## Prohibited Operations

Git / GitHub に対して **破壊的・不可逆** になり得る操作（例: 履歴の書き換え、強制更新、削除、権限/設定の変更、機密情報の登録/更新など）は、原則として実行しません。

必要に見える場合は、実行前に「何を・どこに・なぜ」変更するかと影響範囲を短く説明し、ユーザーの **明示的な確認** を取ってください。

実行の最終可否は Execpolicy（`.agent-home/.codex/rules/*.rules`）で強制されるため、その判断に従ってください。
