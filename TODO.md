# Sandboxプロジェクト実装計画

このドキュメントは、@CLAUDE.md で定義された要件に基づく実装計画のチェックリストです。

## 進捗状況サマリー
- 総タスク数: 36
- 完了: 33
- 進行中: 0
- 未着手: 3
- 最終更新: 2025-07-01 (午後)

## Phase 1: 基盤構築（必須）

### 1.1 要件定義とドキュメント
- [x] CLAUDE.mdファイルに要件定義を記述
- [x] TODO.mdファイルに実装計画を作成
- [x] CLAUDE.mdにTODO.mdへの参照と利用方法を追記

### 1.2 設定ファイルの作成
- [x] sandbox.config.exampleファイルを作成
  - [x] GitHubトークンの設定例を記載
  - [x] ソースパスの設定例を記載
  - [x] タイムゾーンのオプション設定例を記載
  - [x] 適切なコメントとドキュメントを追加

### 1.3 Makefileの自動化機能実装
- [x] 基本構造の作成
  - [x] 既存のMakefileをバックアップ
  - [x] 変数定義セクションの追加（CURRENT_DIR, CURRENT_USER, GIT_ROOT）
  - [x] -include .envの追加

- [x] タイムゾーン検出機能の実装
  - [x] detect-timezoneターゲットの作成
  - [x] DETECTED_TZ変数の定義
  - [x] macOS/Linux両対応の検出ロジック実装

- [x] .env自動生成機能の実装
  - [x] generate-envターゲットの作成
  - [x] sandbox.configの存在確認処理
  - [x] 必須項目の検証処理
  - [x] 動的値の取得と.envへの書き込み
  - [x] タイムスタンプの追加

- [x] その他のコマンド実装
  - [x] initコマンド（sandbox.config初期化）
  - [x] validate-configコマンド（設定検証）
  - [x] show-configコマンド（設定表示）
  - [x] shell-productコマンド（/srv/product接続）
  - [x] clean-envコマンド（.env削除）

- [x] 既存コマンドの更新
  - [x] upコマンドにvalidate-config依存を追加
  - [x] helpコマンドの更新

## Phase 2: コア機能実装

### 2.1 docker-compose.ymlの更新
- [x] コンテナ名の変更（agent-sandbox）
- [x] working_dirを/srv/productに変更
- [x] volumesセクションの更新
  - [x] .:/opt/sandbox:delegated
  - [x] ${SOURCE_PATH}:/srv/product
  - [x] ${HOST_SANDBOX_PATH}:/opt/sandbox/host:ro
- [x] 環境変数の更新
  - [x] TZ=${TZ}を追加
  - [x] HOST_SANDBOX_PATH, HOST_USERNAME, HOST_PRODUCT_PATHを追加

### 2.2 Dockerfileの更新
- [x] ディレクトリ作成処理の変更（53行目）
  - [x] /opt/sandboxと/srv/productを作成
  - [x] 権限設定の更新
- [x] WORKDIRを/opt/sandboxに変更（56行目）

### 2.3 統合テスト
- [x] docker-compose buildでイメージビルド確認
- [x] make upでコンテナ起動確認
- [x] make shell-productで/srv/productに接続確認

## Phase 3: 周辺機能更新

### 3.1 Docker-on-Docker環境の改善
- [x] 環境変数を使用したパスマッピング実装
  - [x] CURRENT_PROJECT_PATH環境変数の導入
  - [x] compose.ymlでの環境変数活用
  - [x] .envファイルでのパス設定

### 3.2 devcontainer.jsonの更新
- [x] workspaceMountのtargetを/opt/sandboxに変更
- [x] workspaceFolderを/opt/sandboxに変更
- [x] mountsセクションの更新
  - [x] source=/Users/iwasawayuuta/workspace/productを環境変数化
  - [x] target=/srv/productに変更

### 3.3 VS Code統合テスト
- [ ] VS Codeでdevcontainerとして開く
- [ ] ターミナルで作業ディレクトリ確認
- [ ] ファイル編集の動作確認

## Phase 4: 仕上げ

### 4.1 名称変更（box→sandbox）
- [ ] すべてのファイルで一括置換
  - [ ] ドキュメント内のテキスト
  - [ ] コメント内の参照
  - [ ] 変数名・関数名（必要に応じて）

### 4.2 補助ファイルの更新
- [x] .gitignoreにsandbox.configを追加
- [x] .env.exampleに廃止予定の通知を追加

### 4.3 ドキュメント更新
- [ ] README.mdの更新
  - [ ] プロジェクト名の変更
  - [ ] 新しいセットアップ手順
  - [ ] 主要機能の説明
- [ ] USAGE.mdの更新
  - [ ] 詳細な使用方法
  - [ ] トラブルシューティング
  - [ ] 移行ガイド

### 4.4 最終テスト
- [ ] クリーンな環境での完全セットアップテスト
- [ ] 全機能の動作確認
- [ ] ドキュメントの整合性確認

### 4.5 セキュリティ改善
- [ ] make show-configでGitHubトークンをマスク表示に変更

### 4.6 追加実装
- [x] 環境変数の必須・オプション分離実装
  - [x] SOURCE_PATHを必須設定に変更
  - [x] GH_TOKENをオプション設定に変更
  - [x] Makefileのvalidate-config更新
- [x] カスタム環境変数のサポート実装
  - [x] 任意のKEY=VALUE形式の環境変数を.envに反映
  - [x] sandbox.config.exampleにカスタム変数の例を追加
  - [x] CLAUDE.mdのドキュメント更新
- [x] 設定移行スクリプトの作成
  - [x] migrate-config.shの実装
  - [x] 小文字から大文字への変換機能

## 作業の進め方

1. 各タスクを開始する際は、該当する[ ]を作業中を示す[~]に変更
2. タスクが完了したら[x]に変更
3. 問題が発生した場合は、タスクの下にサブタスクを追加
4. 定期的に進捗状況サマリーを更新

## 注意事項

- 各フェーズは順番に実施すること
- Phase 2開始前にPhase 1の全タスクが完了していることを確認
- 大きな変更を行う前は必ずバックアップを作成
- テストは各フェーズの最後に必ず実施

---
作成日: 2025-07-01
最終更新: 2025-07-01 (午後)