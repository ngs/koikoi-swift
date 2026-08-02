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
| プライマリ言語 | 日本語 |
| バンドル ID | `io.ngs.Koikoi`（手順 0 の後に選択肢へ出る） |
| SKU | `io.ngs.Koikoi` などで OK |

## 2. Game Center の設定

App ページ → 「Game Center」→ リーダーボードを 2 つ作成:

| ID（コードと一致必須） | 種類 | 提出の意味 | 並び順 |
|---|---|---|---|
| `io.ngs.Koikoi.totalpoints` | 通常（Classic） | 1 対局の獲得文数 | 高い順・ベスト保持 |
| `io.ngs.Koikoi.wins` | 通常（Classic） | 勝利数 | 高い順 |

### ⚠️ wins の注意

現在のコードは勝利のたびに「1」を送信するが、Classic リーダーボードは
**ベストスコア保持**のため全員 1 のまま増えない。
「累計勝利数をローカルで数えて送信する」コード修正が必要（Claude に依頼で即修正）。
totalpoints は「1 対局の最高文数」として意味が通るのでそのままで OK。

## 3. 審査に必要な App レベル設定

- **年齢制限指定**（レーティング審査票）: 未回答だと審査に出せない。
  花札はギャンブルテーマの設問に注意 —
  「シミュレーションギャンブル: なし」（賭博要素なし・得点遊戯）で通るのが通例
- **App プライバシー**: データ収集なし
  （より正確には「ユーザー ID（Game Center）」を申告）
- **価格および配信状況**: 無料 + 配信国

## 4. 初回リリースの流れ（設定完了後）

1. PR #5 → #6 → #7 → #8 をマージ（各マージ後に次の PR の base を master へ切替:
   `gh pr edit <n> --base master`）
2. GitHub Actions → **Release Build and Upload** → Run workflow
   （まず `skip_upload: true` で署名・ビルドの通し確認を推奨）
3. 問題なければ `skip_upload: false` で TestFlight へ。
   以後は master への push → CI green → 自動でリリースビルドが走る

## 設定済み（作業不要）

- GitHub Actions secrets 8 件（ASC API キー `M53276A4TZ`・match パスワード・
  新規 read-only デプロイキー・チーム ID）
- fastlane レーン（ios / mac / visionos）と release.yml
