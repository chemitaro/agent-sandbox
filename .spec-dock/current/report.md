---
種別: 実装報告書
機能ID: "FEATURE-COPILOT-CLI-INTEGRATION"
機能名: "GitHub Copilot CLI を sandbox ツールチェーンへ統合する"
関連Issue: ["10"]
状態: "draft"
作成者: "Codex"
最終更新: "2026-03-19"
依存: ["requirement.md", "design.md", "plan.md"]
---

# FEATURE-COPILOT-CLI-INTEGRATION GitHub Copilot CLI を sandbox ツールチェーンへ統合する — 実装報告（LOG）

## 実装サマリー (任意)
- Copilot wrapper の headless 判定を公式サブコマンドまで拡張し、`init` などを tmux なしで直接実行できるようにした。
- Copilot の tmux セッション名に `CALLER_PWD` 由来の hash を加えて、basename が同じ別ワークスペースで衝突しないようにした。
- 擬似TTYテストは `script -c` 対応環境ではその形式を使い、非対応環境では BSD 形式へフォールバックするようにした。

## 実装記録（セッションログ） (必須)

### 2026-03-19 22:20 - 22:45

#### 対象
- Step: S09
- AC/EC: AC-003, EC-005

#### 実施内容
- `design.md` に公式 headless サブコマンド、Copilot session 名一意化、テスト方針を追補した。
- `plan.md` に S09 を追加し、公式サブコマンド direct exec、session 名衝突回避、擬似TTYテスト移植性を新しい修正ステップとして定義した。
- `host/sandbox` の `copilot_requests_headless_mode()` を拡張し、`init` / `update` / `plugin` / `login` / `logout` を headless 扱いにした。
- `host/sandbox` の `compute_copilot_session_name()` を hash 付きに変更した。
- `tests/sandbox_cli.test.sh` に session 名一意性、`init` direct exec、BSD/util-linux 両対応の `script` helper を追加した。

#### 実行コマンド / 結果
```bash
bash -n host/sandbox tests/sandbox_cli.test.sh
# success

bash tests/sandbox_cli.test.sh
# success
```

#### 変更したファイル
- `.spec-dock/current/design.md` - S09 の設計追補
- `.spec-dock/current/plan.md` - S09 の追加
- `.spec-dock/current/discussions/2026-03-19-copilot-review-analysis-04.md` - 最新レビュー分析
- `host/sandbox` - headless サブコマンド判定と Copilot session 名の修正
- `tests/sandbox_cli.test.sh` - session 名一意性、`init` direct exec、擬似TTY helper のテスト追加

#### コミット
- 未実施

#### メモ
- `compute_codex_session_name()` にも basename 衝突の余地は残るが、今回の修正対象は Copilot レビュー対応に限定した。

## 省略/例外メモ (必須)
- 該当なし
