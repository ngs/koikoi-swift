# AGENTS.md - Guide for AI coding assistants

> **Note**: This file (`AGENTS.md`) is the source of truth. `CLAUDE.md` is a symlink to it — always edit `AGENTS.md`.

## Overview

**Koikoi** — 花札こいこい（任天堂ルール準拠）のマルチプラットフォームアプリ。iPhone / iPad / macOS / Apple Vision Pro。

ルールエンジンは [ngs/go-koikoi](https://github.com/ngs/go-koikoi)（CLI/TUI 版・ブラウザ版 https://koikoi.ngs.io ）の Swift 移植。Go 実装とそのテスト群が仕様書であり、**ルール上の疑義は go-koikoi の実装・テストに合わせる**。セーブデータの札 ID (0–47) も go-koikoi と同一の並びを維持する。

### Stack（tides-swift = Shiomi と同じ規約）

- **Language**: Swift 6 (strict concurrency)
- **Frameworks**: SwiftUI, RealityKit (visionOS), FoundationModels, SwiftData
- **Deployment targets**: iOS 26.0 / macOS 26.0 / visionOS 26.0（FoundationModels 前提）
- **Architecture**: MVVM over local SPM packages
- **Project generation**: Tuist (`Project.swift`) + Swift Package Manager (`Package.swift`)
- **Code quality**: SwiftLint / Periphery
- **CI/CD**: GitHub Actions + fastlane
- **Localization**: String Catalogs（primary language は英語 + 日本語訳）
- **Bundle ID**: `io.ngs.Koikoi`

### Modules

| Module | Path | Contents |
|---|---|---|
| `KoikoiCore` | `Sources/Core/` | 札定義・役判定・ラウンド/対局の状態機械。**Foundation のみ・UI フレームワーク禁止** |
| `KoikoiAI` | `Sources/AI/` | 対戦相手。determinized ISMCTS 探索（打筋の決定）+ FoundationModels のオンデバイス人格（台詞・こいこい判断の説明）。**LLM 不可用時も打筋は探索のみで成立する**（クラウド LLM は使わない = 従量課金ゼロ・オフライン動作） |
| `KoikoiUI` | `Sources/UI/` | SwiftUI ビューとビューモデル（全プラットフォーム共有） |

| Tuist target | Product | Sources | Platforms |
|---|---|---|---|
| `Koikoi` | app | `Sources/App/` | iPhone / iPad / macOS / Vision Pro |
| `KoikoiTests` | unitTests | `Tests/AppTests/` | 同上 |

SPM のテストは `Tests/KoikoiCoreTests/`・`Tests/KoikoiAITests/`（`swift test` で回る。Xcode 不要）。

### 対局の保存（自動保存・起動時復元）

進行中の対局は 1 つだけ Application Support に自動保存する
（`Sources/UI/GameStore.swift`・`Koikoi/current.koikoi`）。起動時に保存があればそのまま復元し、
無ければ対局設定画面から始める（文書ブラウザ / `DocumentGroup` は使わない = ユーザーに
ファイルを意識させない）。保存の中身はシードと全指し手の `GameRecord` で、復元はリプレイによる。
「対局をやめる」で保存は破棄される。`KoikoiGameDocument` と `UTType.koikoiGame` は
visionOS の読み込み（対局設定パネルの「Open Saved Game」= fileImporter）用に残している。

### visionOS

visionOS は平面ウィンドウ移植ではなく **OS の特徴を最大限活かす**方針: volumetric window / RealityKit で札を空間に置き、視線 + ピンチで選択、没入空間（和室・座卓）を提供する。visionOS 固有コードは `Sources/App/` 内で `#if os(visionOS)` または専用ディレクトリに置く。

盤面（`Sources/App/SpatialBoardView.swift`）の構成は、札 = RealityKit のエンティティ、
情報表示 = 2D 版と同じ SwiftUI 部品の RealityView attachment。位置はすべて
`SpatialLayout`（メートル）に集約する。自分の手札は卓から 80 度起こして手前に浮かべ、
獲得札は種類別のパネル（`CapturedDetail`）を卓に伏せて置き、役とリーチ
（`BoardYakuPanel`）は右、スコアボードと対局終了ボタン（`ScoreboardStrip`）は左に
立てる。ダイアログは立てた手札より手前に出す。獲得済みの札は 3D では持たず、
飛来アニメーションが終わったところでエンティティを引き上げてパネルに引き継ぐ。

役パネルとスコアボードは下端の白いバーを掴んで好きな場所へ動かせる。位置は
`SpatialPanelOffsets`（`koikoi.spatial.panelOffsets`）に既定位置からのオフセットとして
保存し、対局設定パネルの「Reset Panel Positions」で捨てる。当たり判定はパネル本体では
なくバーに付ける（本体に付けると中のボタンが押せなくなる）。タップとドラッグは
1 本の `DragGesture` で捌く（別々に付けるとドラッグ側が発火しない）。

### カードアセット

札 48 枚は **SVG ベクター**。旧 Koikoi（Unity 版）の原画を Illustrator の Image Trace でベクター化したものが正で、コミット対象は `Assets/koikoi-swift-assets/KoikoiArtwork.xcassets/Cards/` の imageset のみ（詳細と再生成手順は `Docs/card-assets.md`）。原寸 748×1200・実物比率およそ 5.4:8.7。アセット名は `KoikoiUI` の `Card.assetName` と一致させる（テストで検証される）。

### 絵柄の submodule（MIT 適用外）

絵柄（札 48 枚・アプリアイコン各種・icon-template.svg）は本体リポジトリから切り出し、
**private リポジトリ `ngs/koikoi-swift-assets` を submodule `Assets/koikoi-swift-assets`
として取り込む**。本体は MIT だが絵柄は全て All rights reserved で、この境界は
`LICENSE` の Exceptions 節に明記してある（ライセンス上の線引きなので、**絵柄ファイルを
本体リポジトリへ戻さない**）。

| パス | 中身 |
|---|---|
| `Assets/koikoi-swift-assets/KoikoiArtwork.xcassets/Cards/` | 札 48 枚の imageset |
| `Assets/koikoi-swift-assets/KoikoiArtwork.xcassets/AppIconArtwork.imageset/` | アプリ内表示用のアイコン絵柄 |
| `Assets/koikoi-swift-assets/KoikoiArtwork.xcassets/AppIconVision.solidimagestack/` | visionOS の 3 レイヤーアイコン |
| `Assets/koikoi-swift-assets/AppIcon.icon/` | iOS / macOS の Icon Composer ドキュメント |
| `Assets/koikoi-swift-assets/icon-template.svg` | 3 層を合成したアイコン絵柄の原本 |

`Project.swift` はこのカタログと `AppIcon.icon` をアプリターゲットの resources に
グロブで足している。submodule 未取得だとグロブが空になり、札画像もアイコンも無い
アプリが生成される（プレースホルダーは用意していない）。`swift test` は絵柄を必要と
しないので submodule 無しでも通る。CI は `submodules: recursive` で取得し、private
リポジトリを読める PAT を `secrets.ASSETS_REPO_TOKEN` から渡す。

本体に残る画像は `fastlane/screenshots/` の App Store スクリーンショットのみ
（生成物なので submodule には移さないが、ライセンス上は同じく MIT 適用外）。
`Sources/UI/Resources/Colors.xcassets` は colorset だけで画像を含まないため本体に残す。

## Build & test

```bash
mise install                  # tuist
git submodule update --init   # 絵柄（アプリターゲットのビルドに必須）
swift test                    # KoikoiCore / KoikoiAI（Xcode 不要・まずこれ）
tuist generate --no-open      # Koikoi.xcworkspace を生成
Scripts/lint.sh               # SwiftLint
```

### ローカライズ

**ソースコード内の文字列リテラルは英語のみ。日本語は String Catalog の翻訳値としてのみ持つ。**
Primary language は英語で、`Sources/Core` を含む全モジュールが英語名を正とする
（`YakuKind.displayName`・`Month.monthName` / `flowerName`・`CardType.name`・`Card.name`・
`Difficulty.label`）。go-koikoi の日本語名は各定義のコメントに添える。

| カタログ | バンドル | 中身 |
|---|---|---|
| `Sources/UI/Resources/Localizable.xcstrings` | `Bundle.module`（KoikoiUI） | 役・月・花・難易度・札名と UI 文言 |
| `Sources/UI/Resources/CardTypes.xcstrings` | 同上（テーブル `CardTypes`） | 札種名。役の「Ribbons」（タン）と札種の「Ribbons」（短）は英語が同じで訳が違うため別テーブルにする |
| `Resources/Localizable.xcstrings` | メインバンドル | `Sources/App`（visionOS の操作パネル）の文言 |

Core の英語名をそのままキーにして引く拡張は `Sources/UI/Localization.swift` にある。
KoikoiUI 内のテキストは必ず `bundle: .module` を渡す。翻訳の抜けとキーの漏れは
`Tests/KoikoiUITests/LocalizationTests.swift` が検出する。

## 開発上の注意

- ルール変更・役判定の修正は必ず対応するテストとセットで（go-koikoi のテストを移植したものが基準線）
- ソース内に日本語の文字列リテラルを足さない（表示文言は英語キー + String Catalog の日本語訳）
- 非自明な変更は master 直 push せず feature branch → PR → レビュー経由
- FoundationModels は `SystemLanguageModel.default.availability` を確認し、不可用時は台詞なしで進行（ゲーム進行を LLM 応答でブロックしない）
