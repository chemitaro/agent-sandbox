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
- `Dockerfile` に `TERM=xterm-256color` / `COLORTERM=truecolor` を恒久設定し、`ncurses-term` を追加した。
- `tests/sandbox_term_env.test.sh` を追加し、TERM/COLORTERM と terminfo パッケージの退行を防止した。
- 既存の `tests/sandbox_cli.test.sh` を実行して回帰がないことを確認した。

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

### 2026-02-27 15:15 - 15:30（実装: S01/S02）

#### 対象
- Step: S01, S02
- AC/EC: AC-001, AC-002, AC-004, EC-001

#### 実施内容
- `Dockerfile` の apt インストールに `ncurses-term` を追加。
- `Dockerfile` に `ENV TERM=xterm-256color` / `ENV COLORTERM=truecolor` を追加。
- `tests/sandbox_term_env.test.sh` を新規追加し、上記設定の存在を検査するテストを実装。
- 静的テストと既存テストを実行し、成功を確認。
- 稼働中コンテナを止めていないことを `docker ps` で確認。

#### 実行コマンド / 結果
```bash
bash tests/sandbox_term_env.test.sh
# ==> dockerfile_sets_term_defaults
# ==> dockerfile_has_ncurses_term_package

bash tests/sandbox_cli.test.sh
# all tests passed (exit code 0)

docker ps --format 'table {{.Names}}\t{{.Status}}'
# 稼働中コンテナが継続して Up であることを確認
```

#### 変更したファイル
- `Dockerfile` - `TERM`/`COLORTERM` の恒久設定、`ncurses-term` 追加
- `tests/sandbox_term_env.test.sh` - Dockerfile の環境設定検査テストを追加
- `.spec-dock/current/plan.md` - S01/S02 の完了チェックを反映
- `.spec-dock/current/report.md` - 実装ログを追記

#### コミット
- N/A（このセッションでは未コミット）

#### メモ
- ユーザー要望に合わせ、実装中に既存コンテナの停止操作（`docker stop/down` や `sandbox down`）は実施していない。

---

## 遭遇した問題と解決 (任意)
- 問題: 変更後の runtime 検証（AC-001/002/003）にはイメージ再ビルドと再起動が必要
  - 解決: 本セッションは「実装と静的/既存テスト」まで実施し、runtime 受け入れは S03 として別途実施可能な状態にした

## 学んだこと (任意)
- この環境では `tty: true` のみでは `TERM=xterm` となり、`tput colors=8` になるケースが実際に発生する
- コンテナイメージの `ENV` 固定は `docker compose exec` と `docker exec -it` の両入口を揃えるのに有効

## 今後の推奨事項 (任意)
- S03 として、再ビルド後に手動受け入れ（`tput colors=256` と Codex CLI 目視）を実施する

## 省略/例外メモ (必須)
- 該当なし
