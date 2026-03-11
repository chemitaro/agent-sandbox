---
種別: 実装報告書
機能ID: "fix-fzf-plugin-startup"
機能名: "zsh startup から fzf plugin を外して shell 初期化エラーを防ぐ"
関連Issue: ["user-request-2026-03-11-fzf-plugin"]
状態: "draft"
作成者: "Codex"
最終更新: "2026-03-11"
依存: ["requirement.md", "design.md", "plan.md"]
---

# fix-fzf-plugin-startup — 実装報告（LOG）

## 実装記録（セッションログ） (必須)

### 2026-03-11

#### 対象
- Step: S01, S02, S03
- AC/EC: AC-001, AC-002, EC-001

#### 実施内容
- `Dockerfile` の `zsh-in-docker` plugin 指定から `-p fzf` を除去した。
- `tests/sandbox_term_env.test.sh` に `-p fzf` 不在を確認する静的テストを追加した。
- `fzf` apt package はそのまま残し、plugin 依存だけを外した。

#### 実行コマンド / 結果
```bash
bash tests/sandbox_term_env.test.sh

==> dockerfile_sets_term_defaults
==> dockerfile_has_ncurses_term_package
==> dockerfile_does_not_enable_fzf_plugin

rg -n --fixed-strings -- '-p fzf' Dockerfile || true

# no output

rg -n '^[[:space:]]*fzf \\\\' Dockerfile

45:  fzf \
```

#### 変更したファイル
- `Dockerfile` - `zsh-in-docker` の `fzf` plugin を無効化
- `tests/sandbox_term_env.test.sh` - `-p fzf` 不在の静的テストを追加

#### コミット
- なし

#### メモ
- 議論シート: `.spec-dock/current/discussions/fzf-zsh-root-cause-and-mitigation.md`
- sub-agent セッションは `bwrap` 制約で失敗したため、最小差分のみ main セッションで反映した

## 省略/例外メモ (必須)
- 該当なし
