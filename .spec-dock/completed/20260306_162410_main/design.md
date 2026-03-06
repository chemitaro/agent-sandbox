---
種別: 設計書
機能ID: "CHORE-NODE-LTS-001"
機能名: "Docker イメージで導入する Node.js を 20 系固定から Active LTS へ更新"
関連Issue: ["N/A"]
状態: "draft"
作成者: "Codex CLI"
最終更新: "2026-03-07"
依存: ["requirement.md"]
---

# CHORE-NODE-LTS-001 Docker イメージで導入する Node.js を 20 系固定から Active LTS へ更新 — 設計（HOW）

## 目的・制約（要件から転記・圧縮） (必須)
- 目的: Docker イメージに入る Node.js を 20 系固定から 24 系 Active LTS へ更新する
- MUST:
  - `Dockerfile` の NodeSource セットアップを `setup_24.x` に変更する
  - Node.js 系列の退行防止テストを追加または更新する
  - ビルド後の `node --version` が `v24.` 系になることを確認する
- MUST NOT:
  - `Current` 系へ上げない
  - 依存パッケージ群や CLI 導入対象を変更しない
  - `host/sandbox` / `docker-compose.yml` の仕様を変更しない
- 非交渉制約:
  - 既存テスト（少なくとも `bash tests/sandbox_cli.test.sh`）を壊さない
  - 再現性のため major 固定 (`setup_24.x`) を使う
- 前提:
  - `package.json` の `engines.node >=20.0.0` は 24 系を許容する

---

## 既存実装/規約の調査結果（As-Is / 95%理解） (必須)
- 参照した規約/実装（根拠）:
  - `/srv/mount/box/AGENTS.md`: 日本語コミュニケーション、lowercase path 制約、Conventional Commits
  - `/srv/mount/box/Dockerfile:11-14`: Node.js 20 固定の実装箇所
  - `/srv/mount/box/package.json:6-8`: `engines.node >=20.0.0`
  - `/srv/mount/box/tests/`: Bash テストが Docker 実行を極力避ける構成であること
  - Node.js 公式 previous releases / Release WG: 2026-03-07 時点で `24.x = Active LTS`, `25.x = Current`
- 観測した現状（事実）:
  - `Dockerfile` 冒頭で `setup_20.x` を使っているため、ビルドされる Node.js 系列は 20 に固定されている
  - 既存テストには Node.js 系列専用の検査はなく、Dockerfile を静的に見る Bash テスト追加が既存流儀に合う
- 採用するパターン:
  - Dockerfile の URL とコメントだけを最小変更する
  - 退行防止は Bash による Dockerfile 静的検査で担保する
  - 動作確認はビルド後の `node --version` で行う
- 採用しない/変更しない（理由）:
  - `setup_lts.x` は採用しない（将来 major が変わり、再現性が落ちるため）
  - `package.json` の `engines` は変更しない（要求下限であり、今回の目的は導入系列更新だから）
  - 複数バージョン切替機構は導入しない（要求外）
- 影響範囲:
  - 変更対象: `Dockerfile`, `tests/` の Node.js 系列検査
  - 参照対象: `package.json`, `host/sandbox`, `docker-compose.yml`

## 主要フロー（テキスト：AC単位で短く） (任意)
- Flow for AC-001/003:
  1) 開発者または CI が `Dockerfile` を参照またはテスト実行する
  2) テストが `setup_24.x` を要求し、20 系固定への後戻りを検出する
- Flow for AC-002:
  1) 開発者が更新後のイメージをビルドする
  2) コンテナ内で `node --version` を実行する
  3) `v24.` 系で始まることを確認する

## 判断材料/トレードオフ（Decision / Trade-offs） (任意)
- 論点: `setup_lts.x` と `setup_24.x` のどちらを使うか
  - 選択肢A: `setup_lts.x`
    - Pros: 次の LTS へ自動追従できる
    - Cons: 将来いつ major が変わるかがビルド時点依存になり、再現性が下がる
  - 選択肢B: `setup_24.x`
    - Pros: 2026-03-07 時点の Active LTS を明示的に固定できる
    - Cons: 次の LTS へは再度更新が必要
  - 決定: 選択肢B
  - 理由: 本タスクは「今の最新安定版へ上げる」要求であり、予期しない将来変化を避けるため

## インターフェース契約（ここで固定） (任意)
- IF-ENV-001: Docker イメージに導入される Node.js 系列
  - Input: `Dockerfile` の NodeSource セットアップ URL
  - Output: ビルド後の `node --version`
  - Contract:
    - URL は `setup_24.x`
    - `node --version` は `v24.` 系で始まる

## 変更計画（ファイルパス単位） (必須)
- 追加（Add）:
  - `tests/sandbox_node_version.test.sh`: Dockerfile の Node.js 系列を静的検査する Bash テスト
- 変更（Modify）:
  - `Dockerfile`: NodeSource セットアップ URL とコメントを 24 系へ更新する
  - `host/sandbox`: `tmux` 不在時の判定を環境依存なく扱えるようにする
  - `tests/sandbox_cli.test.sh`: Linux 環境でも既存テストが安定するように docker 不在/TZ 注入の前提を明示的にする
- 参照（Read only / context）:
  - `package.json`: `engines` の整合確認
  - `tests/_helpers.sh`: 既存 Bash テストの作法確認

## マッピング（要件 → 設計） (必須)
- AC-001 → `Dockerfile`, `tests/sandbox_node_version.test.sh`
- AC-002 → `Dockerfile`, 手動確認コマンド `node --version`
- AC-003 → `tests/sandbox_node_version.test.sh`, `tests/sandbox_cli.test.sh`
- EC-001 → `Dockerfile` に `setup_24.x` を固定
- EC-002 → `package.json` は参照のみ、変更なし
- 非交渉制約 → 変更範囲を Dockerfile と Node.js 系列テストへ限定

## テスト戦略（最低限ここまで具体化） (任意)
- 追加/更新するテスト:
  - Unit（静的検査）:
    - `bash tests/sandbox_node_version.test.sh`
      - `Dockerfile` が `setup_24.x` を含む
      - `Dockerfile` が `setup_20.x` を含まない
  - 既存回帰:
    - `bash tests/sandbox_cli.test.sh`
- 手動受け入れ:
  - `./host/sandbox up`
  - `docker exec <started-container> node --version`
- 実行コマンド:
  - `bash tests/sandbox_node_version.test.sh`
  - `bash tests/sandbox_cli.test.sh`
  - `./host/sandbox up`
  - `docker exec <started-container> node --version`

## リスク/懸念（Risks） (任意)
- R-001: Node.js 24 系で CLI 群の互換問題が残る可能性
  - 対応: 今回は Dockerfile と退行防止テストに範囲を絞り、必要なら別タスクで `npm run verify` を追加する
- R-002: NodeSource 24 系の配布内容変更でビルドが揺れる可能性
  - 対応: static test + build verification を組み合わせる

## 未確定事項（TBD） (必須)
- 該当なし

## 省略/例外メモ (必須)
- UML 図は不要（Dockerfile と Bash テストの小規模変更のため）
