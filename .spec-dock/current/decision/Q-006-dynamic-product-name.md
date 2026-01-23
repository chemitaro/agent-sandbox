---
種別: 設計補助資料（意思決定レポート）
機能ID: "FEAT-005"
論点ID: "design.md Q-006（追加予定）"
論点名: "dynamic モードの PRODUCT_NAME を固定値にするか"
作成者: "Codex CLI"
最終更新: "2026-01-21"
関連: ["../design.md", "../requirement.md", "../../Dockerfile", "../../docker-compose.yml"]
---

# Q-006: dynamic モードの `PRODUCT_NAME` を固定値にするか

## 0. この論点は何を決めるか（結論の影響）
dynamic モードはコンテナ内マウント先を `/srv/mount` に固定します（非交渉制約）。  
一方で現行の `Dockerfile` / `docker-compose.yml` では `PRODUCT_NAME` が build arg として使われ、`/srv/${PRODUCT_NAME}` を作る前提があります。

この論点では、dynamic 起動時に `PRODUCT_NAME` をどう扱うかを固定します。

---

## 0.1 決定（ユーザー回答反映）
- 決定: **選択肢A（dynamic は `PRODUCT_NAME=mount` 固定）**

---

## 1. As-Is（根拠）
- `docker-compose.yml` は build args に `PRODUCT_NAME: ${PRODUCT_NAME}` を渡す（`docker-compose.yml:9-10`）。
- `Dockerfile` は `ARG PRODUCT_NAME` → `ENV PRODUCT_NAME` / `ENV PRODUCT_WORK_DIR="/srv/$PRODUCT_NAME"` を設定し、
  `/srv/${PRODUCT_NAME}` を作成している（`Dockerfile:6-10`, `:94-100`）。

---

## 2. 判断基準（評価軸）
1) **/srv/mount 固定との整合**: dynamic の “固定マウント先” とズレないか  
2) **ビルドキャッシュ効率**: 起動ごとに build arg が変わって無駄な再ビルドが発生しないか  
3) **実装変更量**: 既存 Dockerfile/compose への変更が最小か  
4) **理解容易性**: “dynamic は /srv/mount” が一貫して説明できるか  

---

## 3. 選択肢

### 選択肢A（推奨）: dynamic は `PRODUCT_NAME=mount` 固定
#### 3.1 メリット
- Dockerfile の現状仕様に自然に合う（`/srv/mount` が確実に作られる）。
- build arg が固定されるため、**インスタンスごとのキャッシュ分散**を避けられる。
- “dynamic は /srv/mount” という説明が一貫する。

#### 3.2 デメリット
- container 内の `PRODUCT_NAME` はプロジェクト名を表さなくなる（ただし dynamic では用途が薄い）。

---

### 選択肢B: `PRODUCT_NAME` をインスタンスごとに変える（slug 等）
#### 3.3 メリット
- `PRODUCT_NAME` が人間に分かりやすい値になる可能性がある。

#### 3.4 デメリット / リスク
- build arg が変わるたびにキャッシュが分散しやすく、起動が重くなる可能性がある。
- dynamic は `/srv/mount` 固定なので、`PRODUCT_NAME` の有用性が限定的（“見た目のためだけに複雑化” しやすい）。

---

## 4. 推奨案と理由
**決定は A（`PRODUCT_NAME=mount` 固定）**です。

理由:
- `/srv/mount` 固定を最優先しつつ、Dockerfile の変更量を減らせる。
- 起動ごとの build arg 変化を抑え、複数コンテナ並行運用でも重くなりにくい。

---

## 5. あなたが回答するときの項目（コピペ用）
- 回答: A（決定済み）
