#!/bin/bash
# iOS / macOS のアプリアイコンは Resources/AppIcon.icon（Icon Composer で編集）から Xcode が生成する。
# このスクリプトは Icon Composer が扱えない残りを生成する:
#   - visionOS 用 AppIconVision.solidimagestack（前面・中面は AppIcon.icon/Assets の SVG、背面は無地）
#   - アプリ内表示用 AppIconArtwork.imageset（Resources/icon-template.svg = 3 層を合成した絵柄）
# レンダリングは Scripts/render_icon.swift（AppKit）で行う（macOS 標準ツールのみ使用）。
# 絵柄を差し替えるときは AppIcon.icon/Assets の各層と icon-template.svg を揃えて更新すること。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SVG="$REPO_ROOT/Resources/icon-template.svg"
ICON_ASSETS="$REPO_ROOT/Resources/AppIcon.icon/Assets"
VISION_OUT="$REPO_ROOT/Resources/Assets.xcassets/AppIconVision.solidimagestack"

# visionOS は 3 レイヤーの solidimagestack が必須（背面レイヤーは不透明であること）。
echo "visionOS 用 (3 レイヤー):"
rm -rf "$VISION_OUT"
mkdir -p "$VISION_OUT"
cat > "$VISION_OUT/Contents.json" <<'EOF'
{
  "info" : { "author" : "xcode", "version" : 1 },
  "layers" : [
    { "filename" : "Front.solidimagestacklayer" },
    { "filename" : "Middle.solidimagestacklayer" },
    { "filename" : "Back.solidimagestacklayer" }
  ]
}
EOF

# 背面レイヤーは AppIcon.icon のライト時の背景色（icon.json の fill-specializations 先頭）と同じ無地。
BACK_SVG="$(mktemp -t koikoi-icon-back).svg"
trap 'rm -f "$BACK_SVG"' EXIT
cat > "$BACK_SVG" <<'EOF3'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024"><rect width="1024" height="1024" fill="#F4EDDC"/></svg>
EOF3

for layer in Front Middle Back; do
  lower="$(echo "$layer" | tr '[:upper:]' '[:lower:]')"
  src="$ICON_ASSETS/$lower.svg"
  [ "$layer" = "Back" ] && src="$BACK_SVG"
  dir="$VISION_OUT/$layer.solidimagestacklayer"
  mkdir -p "$dir/Content.imageset"
  echo '{ "info" : { "author" : "xcode", "version" : 1 } }' > "$dir/Contents.json"
  cat > "$dir/Content.imageset/Contents.json" <<EOF
{
  "images" : [
    { "filename" : "$layer.png", "idiom" : "vision", "scale" : "2x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
EOF
  swift "$SCRIPT_DIR/render_icon.swift" "$src" "$dir/Content.imageset/$layer.png" 1024
  echo "  $layer.solidimagestacklayer (1024px)"
done

# アプリ内表示用（About 画面など）。AppIcon.icon はコードから参照できないため、
# 同じ SVG を通常の imageset として置き、Image("AppIconArtwork") で全プラットフォームから使う。
ARTWORK_OUT="$REPO_ROOT/Resources/Assets.xcassets/AppIconArtwork.imageset"
echo "アプリ内表示用 (ベクター imageset):"
mkdir -p "$ARTWORK_OUT"
cp "$SVG" "$ARTWORK_OUT/AppIconArtwork.svg"
cat > "$ARTWORK_OUT/Contents.json" <<'EOF2'
{
  "images" : [
    { "filename" : "AppIconArtwork.svg", "idiom" : "universal" }
  ],
  "info" : { "author" : "xcode", "version" : 1 },
  "properties" : { "preserves-vector-representation" : true }
}
EOF2
echo "  AppIconArtwork.imageset"

echo "完了: $VISION_OUT, $ARTWORK_OUT"
