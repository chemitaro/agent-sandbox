# Node.js リリースチャネル判断メモ

## 結論
- 2026-03-07 時点の「最新安定版」は `Active LTS` と解釈する。
- 実装では `setup_lts.x` のような可変エイリアスではなく `setup_24.x` を使う。

## 根拠
- Node.js 公式の previous releases では、2026-03-07 時点で `24.x = Active LTS`, `25.x = Current`。
- Node.js 公式は production 利用で LTS 系を推奨している。
- `package.json` の `engines.node >=20.0.0` は 24 系と矛盾しない。

## 採用しなかった案
- `Current (25.x)`
  - 理由: 「最新」ではあるが、「安定版」という表現と production 推奨の文脈に合いにくい。
- `setup_lts.x`
  - 理由: 将来の LTS 切替で指す major が変わり、再現性が落ちる。

## 実装への影響
- Dockerfile は `setup_24.x` へ更新する。
- テストは 20 系固定の残存を検出し、24 系固定を確認する。
