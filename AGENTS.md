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
- **Localization**: String Catalogs（開発言語は英語 + 日本語）
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

### visionOS

visionOS は平面ウィンドウ移植ではなく **OS の特徴を最大限活かす**方針: volumetric window / RealityKit で札を空間に置き、視線 + ピンチで選択、没入空間（和室・座卓）を提供する。visionOS 固有コードは `Sources/App/` 内で `#if os(visionOS)` または専用ディレクトリに置く。

### カードアセット

札 48 枚は **SVG ベクター**。旧 Koikoi（Unity 版）の原画を Illustrator の Image Trace でベクター化したものが正で、コミット対象は `Resources/Assets.xcassets/Cards/` の imageset のみ（詳細と再生成手順は `Docs/card-assets.md`）。原寸 748×1200・実物比率およそ 5.4:8.7。アセット名は `KoikoiUI` の `Card.assetName` と一致させる（テストで検証される）。

## Build & test

```bash
mise install               # tuist
swift test                 # KoikoiCore / KoikoiAI（Xcode 不要・まずこれ）
tuist generate --no-open   # Koikoi.xcworkspace を生成
Scripts/lint.sh            # SwiftLint
```

## 開発上の注意

- ルール変更・役判定の修正は必ず対応するテストとセットで（go-koikoi のテストを移植したものが基準線）
- 非自明な変更は master 直 push せず feature branch → PR → レビュー経由
- FoundationModels は `SystemLanguageModel.default.availability` を確認し、不可用時は台詞なしで進行（ゲーム進行を LLM 応答でブロックしない）
