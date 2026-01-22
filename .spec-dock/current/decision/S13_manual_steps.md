# S13 手動検証手順（Docker / DoD 確認）

この手順は **Docker を使える環境** で実施してください。
本リポジトリの `sandbox` コマンド（または `./host/sandbox`）で DoD（Docker-on-Docker）を確認します。

## 前提
- Docker デーモンが起動している
  - 例: Docker Desktop / OrbStack など
- 対象プロジェクトが存在する
  - 推奨: `/Users/iwasawayuuta/workspace/product/taikyohiyou_project`

## 0. Docker 疎通確認
```bash
docker info >/dev/null 2>&1 && echo "Docker OK" || echo "Docker NG"
```
- `Docker OK` が出れば次へ進む

## 1. sandbox コマンドの用意
- インストール済みの場合:
```bash
sandbox help
```
- 未インストールの場合はリポジトリ直下から実行:
```bash
./host/sandbox help
```

## 2. 対象プロジェクトへ移動
```bash
cd /Users/iwasawayuuta/workspace/product/taikyohiyou_project
```

## 3. シェル起動（DoD 実動）
```bash
# インストール済み
sandbox shell

# 未インストールの場合
/path/to/agent-sandbox/host/sandbox shell
```

## 4. コンテナ内で DoD 確認
```bash
# Docker-on-Docker が使えること
 docker version

# DoD のパス変換が成り立つこと
 ./scripts/git/detect_git_env.sh

# 参考: 期待される値
 echo "$HOST_PRODUCT_PATH"
 echo "$PRODUCT_WORK_DIR"
```
期待値の目安:
- `docker version` が失敗しない
- `HOST_PRODUCT_PATH` がホストの `abs_mount_root`
- `PRODUCT_WORK_DIR` が `/srv/mount`
- `detect_git_env.sh` の結果で、コンテナ内→ホストパス変換が成立している

## 5. 終了と確認（任意）
```bash
exit
sandbox status
sandbox down
```

## 6. 記録
- 成功/失敗、出力の要点を `.spec-dock/current/report.md` に追記
- 失敗時はエラーメッセージを記録
