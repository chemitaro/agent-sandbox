---
種別: 実装報告書
機能ID: "CHORE-TUI-COLOR-001"
機能名: "コンテナ内の色数（TERM/COLORTERM）を安定化して Codex CLI の表示崩れを解消"
関連Issue: ["N/A"]
状態: "draft"
作成者: "Codex CLI"
最終更新: "2026-02-26"
依存: ["requirement.md", "design.md", "plan.md"]
---

# CHORE-TUI-COLOR-001 コンテナ内の色数（TERM/COLORTERM）を安定化して Codex CLI の表示崩れを解消 — 実装報告（LOG）

## 実装サマリー (任意)
- [実装した内容の概要を2-3文で記載]

## 実装記録（セッションログ） (必須)

### 2026-02-26 20:30 - 22:30（計画/調査）

#### 対象
- Step: （計画フェーズ）requirement/design/plan 作成
- AC/EC: AC-001〜004, EC-001/002（前提整理）

#### 実施内容
- ChatGPT 共有メモ（TERM/COLORTERM 低下による低色数フォールバック）を踏まえ、リポ内の実装/設定を調査。
- 端末能力（色数）を `TERM`/`COLORTERM` で観測し、コンテナ内で `tput colors=8` になっていることを確認。
- `.spec-dock/current/requirement.md` を作成し、ユーザー回答（常時設定/`docker exec -it` も対象）を反映。
- `.spec-dock/current/design.md` / `.spec-dock/current/plan.md` をドラフト作成。

#### 実行コマンド / 結果
```bash
echo "HOST TERM=${TERM-}"
echo "HOST COLORTERM=${COLORTERM-}"
# HOST TERM=xterm-ghostty
# HOST COLORTERM=truecolor

# コンテナ（docker compose exec）
docker compose exec agent-sandbox /bin/zsh -lc 'echo "TERM=$TERM"; echo "COLORTERM=$COLORTERM"; tput colors'
# TERM=xterm
# COLORTERM=
# 8

# コンテナ（docker exec -it）
docker exec -it sandbox-box-87a7e19a9e8f /bin/zsh -lc 'echo "TERM=$TERM"; echo "COLORTERM=$COLORTERM"; tput colors'
# TERM=xterm
# COLORTERM=
# 8

# 上書きでの改善確認（参考）
docker exec -it -e TERM=xterm-256color -e COLORTERM=truecolor sandbox-box-87a7e19a9e8f /bin/zsh -lc 'echo "TERM=$TERM"; echo "COLORTERM=$COLORTERM"; tput colors'
# TERM=xterm-256color
# COLORTERM=truecolor
# 256
```

#### 変更したファイル
- `.spec-dock/current/requirement.md` - 要件定義（AC/EC/TBD解消）
- `.spec-dock/current/design.md` - 設計ドラフト
- `.spec-dock/current/plan.md` - 実装計画ドラフト

#### コミット
- N/A（未実装）

#### メモ
- 本タスクは「色数が少ない/合わない」をまず解消するため、コンテナ作成時点の環境変数（`TERM/COLORTERM`）を恒久化する設計とする。

---

### YYYY-MM-DD HH:MM - HH:MM

#### 対象
- Step: ...
- AC/EC: ...

#### 実施内容
- ...

---

## 遭遇した問題と解決 (任意)
- 問題: ...
  - 解決: ...

## 学んだこと (任意)
- ...
- ...

## 今後の推奨事項 (任意)
- ...
- ...

## 省略/例外メモ (必須)
- 該当なし
