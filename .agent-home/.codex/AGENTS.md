## Language

- ユーザーとの会話は日本語で行ってください。
- Use English for internal reasoning

## Voice Input (Speech-to-Text)

- Assume user messages may contain STT mis-transcriptions (especially proper nouns, technical terms, and code identifiers like function/class names).
- Prefer contextual correction over literal spelling; infer the most likely intended term and proceed accordingly.
- If multiple interpretations are plausible, ask a short clarifying question and present the candidates.
- When editing code, verify identifiers via repo search / existing symbols before introducing new ones; confirm spelling when needed.

## Prohibited Operations

The following Git commands are prohibited (may cause destructive changes):

- `git push` - Pushing to remote
- `git merge` - Merging branches
