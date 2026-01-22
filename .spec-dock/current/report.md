---
種別: 実装報告書
機能ID: "FEAT-005"
機能名: "動的マウント起動（任意ディレクトリをSandboxとして起動）"
関連Issue: ["https://github.com/chemitaro/agent-sandbox/issues/5"]
状態: "draft"
作成者: "Codex CLI"
最終更新: "2026-01-22"
依存: ["requirement.md", "design.md", "plan.md"]
---

# FEAT-005 動的マウント起動（任意ディレクトリをSandboxとして起動） — 実装報告（LOG）

## 実装サマリー (任意)
- （未記載 / 設計フェーズ）

## 実装記録（セッションログ） (必須)

### 2026-01-22 - 2026-01-22 15:26

#### 対象
- Step: （未着手 / 設計更新）
- AC/EC: AC-020

#### 実施内容
- `sandbox status` コマンドの仕様追加（要件/設計の更新）。
- 出力内容（container_name/status/container_id/mount_root/workdir）と exit code 方針（存在しない場合も exit 0）を固定。

#### 実行コマンド / 結果
```bash
# ドキュメントの参照（抜粋）
sed -n '1,260p' .spec-dock/current/requirement.md
sed -n '1,260p' .spec-dock/current/design.md
rg -n "sandbox status|AC-020" .spec-dock/current/requirement.md .spec-dock/current/design.md
```

#### 変更したファイル
- `.spec-dock/current/requirement.md` - `sandbox status`（AC-020）を追加
- `.spec-dock/current/design.md` - IF-CLI-001/具体設計/マッピング/テスト戦略に `sandbox status` を反映

#### コミット
- （未実施 / 禁止）

#### メモ
- 実装/テストはまだ着手しない（設計フェーズ）。

---

### 2026-01-22 15:26 - 2026-01-22 15:46

#### 対象
- Step: （未着手 / 設計更新）
- AC/EC: AC-018, AC-019, AC-020

#### 実施内容
- レビューフィードバックを反映し、以下を仕様として明確化:
  - `help/name/status` は副作用なし（`.env` / `.agent-home` の作成を含むホスト側ファイル生成/更新をしない）
  - `workdir=PWD` の `PWD` は “呼び出し元PWD”（`CALLER_PWD`）である
  - ヘルプはパス検証より先に処理し、無効なパス指定が混ざっていても exit 0 で表示できる
  - `TZ=` が空文字の場合は未設定扱いとして検出注入する（空のままにしない）
  - コンテナ存在確認を `docker ps -a` の出力パースではなく `docker inspect` ベースに寄せる

#### 実行コマンド / 結果
```bash
rg -n "CALLER_PWD|help --workdir|docker inspect|TZ=\\)" .spec-dock/current/design.md .spec-dock/current/requirement.md
```

#### 変更したファイル
- `.spec-dock/current/requirement.md` - help/name/status の副作用なし・ヘルプの早期処理・呼び出し元PWDの明記
- `.spec-dock/current/design.md` - CALLER_PWD 固定、compose事前準備の適用範囲、TZ空文字ルール、存在確認の inspect 化、テスト観点を追記

#### コミット
- （未実施 / 禁止）

#### メモ
- まだ設計フェーズ。次はユーザー承認後に `plan.md` を作成して実装へ進む。

---

### 2026-01-22 15:46 - 2026-01-22 16:14

#### 対象
- Step: （計画フェーズ / ドキュメント更新）
- AC/EC: AC-015, AC-016, AC-018, AC-020, EC-005

#### 実施内容
- レビューフィードバックを反映し、以下を仕様として明確化:
  - 用語統一: `PWD` 表記を “呼び出し元PWD（= sandbox 実行時のPWD）” に統一
  - `-h/--help` は **引数のどこに現れても最優先**（`sandbox shell --workdir /nope --help` でも exit 0）
  - `stop/down` は “対象なし” が確定した場合は **真に no-op**（`docker compose` を呼ばず、`.env/.agent-home` も作らない）
  - Docker/Compose 不在・デーモン疎通不可は `not-found` と区別して **非0でエラー**（EC-005）
  - `name/status` の stdout 契約を守るため、デバッグログは stderr に寄せる方針を追加
- `.spec-dock/current/plan.md` を FEAT-005 の実装計画として作成（ステップ分割/要件マッピング）。

#### 実行コマンド / 結果
```bash
rg -n "\\bPWD\\b|-h/--help|no-op|EC-005|stderr" .spec-dock/current/requirement.md .spec-dock/current/design.md
sed -n '1,120p' .spec-dock/current/plan.md
```

#### 変更したファイル
- `.spec-dock/current/requirement.md` - PWD表記統一、help優先順位、stop/down no-op、EC-005、stdout/stderr方針
- `.spec-dock/current/design.md` - help優先順位（どこでも）、0.1適用範囲、stop/down no-op、docker疎通/失敗分類、stdout/stderr方針
- `.spec-dock/current/plan.md` - 実装計画を記述（S01-S12）

#### コミット
- （未実施 / 禁止）

#### メモ
- 次は plan.md に従って実装フェーズへ進む（ユーザー承認後）。

## 遭遇した問題と解決 (任意)
- 該当なし

## 学んだこと (任意)
- 該当なし

## 今後の推奨事項 (任意)
- 該当なし

## 省略/例外メモ (必須)
- 該当なし
