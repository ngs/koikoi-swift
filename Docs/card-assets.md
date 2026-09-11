# 花札カードアセット

札 48 枚は SVG ベクター。旧 Koikoi（Unity 版）のカード原画
（`Dropbox/Codes/Koikoi/Assets/Sprites/Cards/{月:02d}-{連番:02d}.jpg`）を
Illustrator の Image Trace でベクター化したものを正とする。

コミット対象は **`Assets/koikoi-swift-assets/KoikoiArtwork.xcassets/Cards/` の imageset のみ**
（preserves-vector-representation 付き SVG）。中間生成物は `/tmp` に置き、コミットしない。

絵柄は MIT 適用外のため、本体ではなく private submodule
（`ngs/koikoi-swift-assets` → `Assets/koikoi-swift-assets`）に置く。**再生成すると
submodule の作業ツリーが変わるので、commit / push は submodule 側で行い、本体側では
submodule のポインタ更新を別途 commit する。**

## パイプライン（Scripts/trace_cards.sh が一括実行）

```
旧 Koikoi の JPG（748×1200）
  │  Scripts/pretrace_cards.py     … 紙テクスチャ除去（彩度≤12 かつ min(RGB)≥195 → 純白）
  ▼
/tmp/koikoi_pretrace/*.png
  │  Scripts/trace_cards.jsx       … Illustrator Image Trace（フルカラー）→ SVG
  ▼
/tmp/koikoi_traced/{id:02d}_{slug}.svg
  │  Scripts/cards_to_xcassets.sh  … imageset 化（Cards フォルダだけを再生成）
  ▼
Assets/koikoi-swift-assets/KoikoiArtwork.xcassets/Cards/{id:02d}_{slug}.imageset   ← コミット対象（submodule 側）
```

- 札 ID (0–47) と並びは go-koikoi の `AllCards` と同一。`id = (月-1)×4 + (連番-1)`
- アセット名は `KoikoiUI` の `Card.assetName`（`Sources/UI/CardAssets.swift`）と
  一致させる。整合性は `KoikoiUITests` / `AppTests` が検証する
- 原寸 748×1200（実物比率 約 5.4:8.7）。`Card.aspectRatio` に反映済み

## 再生成

```bash
Scripts/trace_cards.sh   # 前処理 + Illustrator トレース + xcassets 反映まで一括
```

前提: Adobe Illustrator、`python3` + Pillow + NumPy（`pip3 install pillow numpy`）、
および絵柄 submodule の取得（`git submodule update --init`）。
原画の場所は `KOIKOI_SPRITES_DIR` で上書きできる。
