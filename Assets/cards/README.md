# 花札カードアセット

48 枚すべて SVG ベクター。旧 Koikoi（Unity 版）のカード原画
（`Dropbox/Codes/Koikoi/Assets/Sprites/Cards/{月:02d}-{連番:02d}.jpg`）を
Illustrator の Image Trace でベクター化したものを正とする。

## パイプライン

```
旧 Koikoi の JPG（748×1200）
  │  Scripts/pretrace_cards.py       … 紙テクスチャ除去（彩度≤12 かつ min(RGB)≥195 → 純白）
  ▼
/tmp/koikoi_pretrace/*.png
  │  Scripts/trace_cards.jsx         … Illustrator Image Trace（フルカラー）→ SVG
  │  （Scripts/trace_cards.sh が上 2 段をまとめて実行）
  ▼
Assets/cards/traced/{id:02d}_{slug}.svg   ← コミットする成果物（本ディレクトリ）
  │  Scripts/cards_to_xcassets.sh    … imageset 化（preserves-vector-representation）
  ▼
Resources/Assets.xcassets/Cards/{id:02d}_{slug}.imageset
```

- 札 ID (0–47) と並びは go-koikoi の `AllCards` と同一。`id = (月-1)×4 + (連番-1)`
- アセット名は `KoikoiUI` の `Card.assetName`（`Sources/UI/CardAssets.swift`）と
  一致させる。整合性は `KoikoiUITests` / `AppTests` が検証する
- 原寸 748×1200（実物比率 約 5.4:8.7）。`Card.aspectRatio` に反映済み
- `traced/trace_log.txt` はトレース実行ログ（git 管理外）

## 再生成

```bash
Scripts/trace_cards.sh        # 前処理 + Illustrator 一括トレース（要 Illustrator）
Scripts/cards_to_xcassets.sh  # xcassets へ反映
```

前提: Adobe Illustrator、`python3` + Pillow + NumPy（前処理に使用。
`pip3 install pillow numpy`）。原画の場所は `KOIKOI_SPRITES_DIR` で上書きできる。

## 将来のフラットデザイン化

モダンフラットな再解釈で描き直す構想がある。Firefly 用プロンプト一式を
`firefly-prompts.md` に保存済み（スタイル文 + 48 枚の主題文）。
