---
種別: 設計書
機能ID: "GC-001"
機能名: "未使用ファイルの棚卸しと削除"
関連Issue: ["TBD"]
状態: "draft"
作成者: "Codex"
最終更新: "2026-01-23"
依存: ["requirement.md"]
---

# GC-001 未使用ファイルの棚卸しと削除 — 設計（HOW）

## 目的・制約（要件から転記・圧縮） (必須)
- 目的: 未使用ファイルを根拠付きで棚卸しし、確認後に削除する。
- MUST: リポジトリ全体の棚卸し、用途分析、削除、参照残存チェック。
- MUST NOT: 使用中ファイルやローカル運用ファイル（`.env`, `.agent-home`）の削除、機能追加。
- 非交渉制約: CLI/コンテナ起動フローを壊さない。禁止 Git 操作は実施しない。`sandbox.config` は削除対象、`sandbox.config.example` は `.env.example` にリネームして保持。
- 前提: 静的参照確認で一次判定が可能。

---

## 既存実装/規約の調査結果（As-Is / 95%理解） (必須)
- 参照した規約/実装（根拠）:
  - `host/sandbox`: CLI のエントリ。SANDBOX_ROOT と .agent-home の作成、docker compose の起動準備を行う。(`host/sandbox`:52-108,183-220)
  - `docker-compose.yml`: `agent-sandbox` のビルド/ボリューム/環境変数を定義。(`docker-compose.yml`:1-58)
  - `Dockerfile`: `scripts/*` をコンテナに配置し、エントリポイントを `docker-entrypoint.sh` に設定。(`Dockerfile`:191-223)
  - `scripts/generate-git-ro-overrides.sh`: Git metadata を read-only でマウントするための override 生成（削除済み）。(`scripts/generate-git-ro-overrides.sh`:1-108)
  - `docker-compose.git-ro.yml`: `volumes: []` のみで read-only 仕様を無効化した痕跡（削除済み）。(`docker-compose.git-ro.yml`:1-5)
  - `Makefile`: `scripts/install-sandbox.sh` / `scripts/get-tmux-session.sh` を呼び出す。(`Makefile`:5-26)
- 観測した現状（事実）:
  - `product/` は空ディレクトリで `.keep` のみ存在していた（削除済み）。
  - `git log` の大きな変更は PR #6 (`317aefd`, `chemitaro/issue5`) に集約されている。
- 採用するパターン（命名/責務/例外/DI/テストなど）:
  - 参照調査は `rg` を基準に行い、参照が無いことを明示的に証明する。
  - 判断は「削除可」「保留（用途確認）」「保持」の3分類で整理する。
- 採用しない/変更しない（理由）:
  - 実行フローや設定の再設計は行わない（削除に限定）。
- 影響範囲（呼び出し元/関連コンポーネント）:
  - `host/sandbox` / `Dockerfile` / `docker-compose.yml` / `scripts/*` / `tests/*` / `Makefile`

## 主要フロー（テキスト：AC単位で短く） (任意)
- Flow for AC-001:
  1) 全ファイルを一覧化
  2) 参照調査
  3) 「削除可/保留/保持」に分類して根拠を記録
- Flow for AC-002:
  1) 削除対象を確定
  2) 削除実施
  3) 参照残存チェック
- Flow for AC-003:
  1) テスト/動作確認を実施
  2) 結果を記録

## 判断材料/トレードオフ（Decision / Trade-offs） (任意)
- 論点: 未使用判定の厳密度
  - 選択肢A: 参照が無いものは即削除
  - 選択肢B: 参照が無いものも用途確認を経て削除
  - 決定: B
  - 理由: 外部参照・運用依存のリスクを回避するため

## 変更計画（ファイルパス単位） (必須)
- 追加（Add）:
  - `.spec-dock/current/discussions/garbage-files.md`: 未使用候補の棚卸し結果と根拠の記録
- 変更（Modify）:
  - `Makefile`: `install` / `help` のみに整理し、不要変数と古いヘルプを削除
  - `README.md` / `CLAUDE.md`: 削除対象が記載されている場合のみ参照更新
- 削除（Delete）:
  - `sandbox.config`: 役目を終えたため削除
  - その他、棚卸し結果で確定した未使用ファイル
- 移動/リネーム（Move/Rename）:
  - `sandbox.config.example` → `.env.example`: 例示ファイルとして保持
- 保持（Keep）:
  - `.env.example`（存在する場合）: Slack/Webhook/Token 例の保持目的
  - `.agent-home/`: 検査対象外・保持
- 参照（Read only / context）:
  - `host/sandbox`, `Dockerfile`, `docker-compose.yml`, `scripts/*`, `tests/*`, `Makefile`

## マッピング（要件 → 設計） (必須)
- AC-001 → `.spec-dock/current/discussions/garbage-files.md`, `rg` による参照調査, 参照元記録
- AC-002 → 削除対象の確定、参照残存チェック（`rg`）
- AC-003 → `tests/*.sh` の実行結果（可能なら実施、不可なら理由記録）
- 非交渉制約 → 参照が不明なものは削除しない、禁止 Git 操作を実施しない

## テスト戦略（最低限ここまで具体化） (任意)
- 追加/更新するテスト:
  - 追加なし（削除のみ）
- どのAC/ECをどのテストで保証するか:
  - AC-003 → `bash tests/sandbox_cli.test.sh` など既存シェルテスト（実行可能な範囲）
- 非交渉制約（requirement.md）をどう検証するか:
  - CLI/起動フロー維持: `host/sandbox` の参照切れが無いことを `rg` で確認
- 実行コマンド（該当するものを記載）:
  - `bash tests/sandbox_cli.test.sh`
  - `bash tests/sandbox_paths.test.sh`
- 変更後の運用（必要なら）:
  - なし

## リスク/懸念（Risks） (任意)
- R-001: 外部参照のみのファイルを削除してしまう
  - 対応: 保留カテゴリとヒアリングで回避

## 未確定事項（TBD） (必須)
- 該当なし

---

## ディレクトリ/ファイル構成図（変更点の見取り図） (任意)
```text
<repo-root>/
├── host/
│   └── sandbox
├── scripts/
│   ├── docker-entrypoint.sh
│   ├── init-firewall.sh
│   ├── slack-notify.js
│   ├── tmux-claude
│   ├── tmux-codex
│   └── tmux-opencode
├── tests/
│   └── *.sh
├── docker-compose.yml
├── docker-compose.git-ro.yml  # Delete? (棚卸し結果で確定)
├── Dockerfile
├── Makefile
├── sandbox.config             # Delete
├── sandbox.config.example     # Rename -> .env.example
└── product/
    └── .keep                  # Delete? (棚卸し結果で確定)
```

## 省略/例外メモ (必須)
- UML/IF契約/データ設計は削除作業のため省略
