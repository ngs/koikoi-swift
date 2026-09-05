# App Store Connect セットアップ手順

チーム: LittleApps（Team ID `3Y8APYUG2G` / ITC Team `301484`、Shiomi と同じ組織）

## 0. 前提: Bundle ID とプロビジョニング（Claude が代行可能）

CI の match は `MATCH_READONLY=true` で動くため、**初回のプロファイル生成だけ
ローカル実行が必要**。

```bash
# Dropbox/Credentials/apple/LittleApps の環境変数を読み込んだ上で
MATCH_READONLY=false bundle exec fastlane ios release_match
MATCH_READONLY=false bundle exec fastlane mac release_match
```

→ App ID `io.ngs.Koikoi` の作成と証明書/プロファイルが
littleapps-fastlane-certificates リポジトリに保存される。
**Claude に「match 初回実行お願い」と言えば代行します。**

## 1. アプリレコードの作成（手作業）

https://appstoreconnect.apple.com → マイ App → 「+」→ 新規 App

| 項目 | 値 |
|---|---|
| プラットフォーム | iOS・macOS・visionOS の 3 つにチェック（1 レコード共通） |
| 名前 | App Store 上でユニーク必須（「Koikoi」は競合の可能性大。候補:「こいこい - Koikoi」） |
| プライマリ言語 | 英語（アプリの primary language に合わせる。作成時に日本語にした場合は App 情報から英語へ変更） |
| バンドル ID | `io.ngs.Koikoi`（手順 0 の後に選択肢へ出る） |
| SKU | `io.ngs.Koikoi` などで OK |

## 2. Game Center の設定

App ページ → 「Game Center」→ リーダーボードを 2 つ作成:

| ID（コードと一致必須） | 種類 | 提出の意味 | 並び順 |
|---|---|---|---|
| `io.ngs.Koikoi.totalpoints` | 通常（Classic） | 1 対局の獲得文数 | 高い順・ベスト保持 |
| `io.ngs.Koikoi.wins` | 通常（Classic） | 勝利数 | 高い順 |

### wins の送信について

Classic リーダーボードはベストスコア保持のため、コードは累計勝利数をローカルで
数えてから送信する（`GameCenterService.reportMatchEnd`）。totalpoints は
「1 対局の最高文数」。

## 3. 審査に必要な App レベル設定

- **年齢制限指定**（レーティング審査票）: 未回答だと審査に出せない。
  花札はギャンブルテーマの設問に注意 —
  「シミュレーションギャンブル: なし」（賭博要素なし・得点遊戯）で通るのが通例
- **App プライバシー**: データ収集なし
  （より正確には「ユーザー ID（Game Center）」を申告）
- **価格および配信状況**: 無料 + 配信国

## 4. リリースの流れ

master への push → CI green → **Release Build and Upload** が自動で走り TestFlight へ
アップロードされる（手動実行時は `skip_upload: true` で署名・ビルドの通し確認ができる）。
メタデータの更新は `bundle exec fastlane <ios|mac> deliver_metadata`。

## 5. 提出前に残っている手作業

- スクリーンショット（`fastlane/screenshots/` は空。iPhone 6.9"/6.5"、iPad 13"、Mac、Vision Pro）
- ASC で審査提出（ビルド選択・年齢制限票の確認）

## 設定済み（作業不要）

- GitHub Actions secrets 8 件（ASC API キー `M53276A4TZ`・match パスワード・
  新規 read-only デプロイキー・チーム ID）
- fastlane レーン（ios / mac / visionos）と release.yml
