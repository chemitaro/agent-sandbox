---
種別: 実装報告書
機能ID: "FEAT-SANDBOX-CODEX-RUNTIME-TRUST-001"
機能名: "sandbox codex の runtime trust 注入（最大権限デフォルトと skills 有効化）"
関連Issue: []
状態: "draft"
作成者: "Codex CLI"
最終更新: "2026-01-25"
依存: ["requirement.md", "design.md", "plan.md"]
---

# FEAT-SANDBOX-CODEX-RUNTIME-TRUST-001 sandbox codex の runtime trust 注入（最大権限デフォルトと skills 有効化） — 実装報告（LOG）

## 実装サマリー (任意)
- （未実装: 計画フェーズ）

## 実装記録（セッションログ） (必須)

### 2026-01-25 00:00 - 00:00

#### 対象
- Step: （計画フェーズ）
- AC/EC: AC-001〜AC-004, EC-001〜EC-003

#### 実施内容
- レビュー反映:
  - `--git-common-dir` 相対パスの扱いを設計に明記
  - user `-c/--config projects...` を禁止する仕様を追加
  - 手動受け入れ手順（AC-002）を `.spec-dock/current/discussions/manual-acceptance-ac002.md` に具体化
  - 実装計画書（TDD）を `.spec-dock/current/plan.md` として作成
- 事実確認:
  - Codex CLI のヘルプで `-a/-s/-C/-c` の仕様を確認（`codex --help` 等）
  - Codex TUI の `/skills`（slash command）存在を OSS コードで確認し、手動受け入れの観測点に採用
  - 既存テストが「永続 config.toml 作成」を期待しており、現状の `host/sandbox` と不整合で失敗することを確認（S01 で置換予定）

#### 実行コマンド / 結果
```bash
codex --version
# codex-cli 0.89.0

codex --help
codex resume --help
codex exec --help

bash tests/sandbox_cli.test.sh
# 失敗:
# ==> shell_trusts_git_repo_root_for_codex
# Expected Codex config.toml to be created: .../.agent-home/.codex/config.toml
```

#### 変更したファイル
- `.spec-dock/current/requirement.md`
- `.spec-dock/current/design.md`
- `.spec-dock/current/plan.md`
- `.spec-dock/current/discussions/manual-acceptance-ac002.md`
- `.spec-dock/current/discussions/questions-for-user.md`
- `.spec-dock/current/report.md`

#### コミット
- 実施しない（禁止コマンド）

#### メモ
- 次回は `plan.md` の S01 から着手し、テストを新仕様へ置換した上で TDD 実装に進む。

---

## 遭遇した問題と解決 (任意)
- （未実装）

## 学んだこと (任意)
- （未実装）

## 今後の推奨事項 (任意)
- （未実装）

## 省略/例外メモ (必須)
- 該当なし
