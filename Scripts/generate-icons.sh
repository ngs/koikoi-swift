#!/bin/bash
# Resources/icon-template.svg から AppIcon.appiconset とアプリ内表示用の AppIconArtwork.imageset を生成する。
# レンダリングは Scripts/render_icon.swift（AppKit）で行う（macOS 標準ツールのみ使用）。
# macOS アイコンは MAC_INSET（既定 0）でマージン + 角丸を任意に適用できる。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SVG="$REPO_ROOT/Resources/icon-template.svg"
OUT="$REPO_ROOT/Resources/Assets.xcassets/AppIcon.appiconset"
VISION_OUT="$REPO_ROOT/Resources/Assets.xcassets/AppIconVision.solidimagestack"

mkdir -p "$OUT"

render() { # px out radius margin
  swift "$SCRIPT_DIR/render_icon.swift" "$SVG" "$OUT/$2" "$1" "${3:-0}" "${4:-0}"
  echo "  $2 (${1}px)"
}

echo "iOS/visionOS 用 (フルブリード):"
render 1024 icon-ios-1024.png

# macOS 用のインセット比率。背景つきの角丸四角アイコンなら Apple 流儀の 0.098 を指定する。
# 現在のアイコンは背景なしの自立した形（SVG 自体に余白を含む）なので 0 = フルブリード。
MAC_INSET="${MAC_INSET:-0}"

echo "macOS 用 (インセット $MAC_INSET):"
for entry in 16:1 16:2 32:1 32:2 128:1 128:2 256:1 256:2 512:1 512:2; do
  size="${entry%%:*}"; scale="${entry##*:}"
  px=$((size * scale))
  margin=$(awk "BEGIN { print $px * $MAC_INSET }")
  radius=$(awk "BEGIN { if ($MAC_INSET > 0) print ($px - 2 * $px * $MAC_INSET) * 0.2237; else print 0 }")
  suffix=""
  [ "$scale" = "2" ] && suffix="@2x"
  render "$px" "icon-mac-${size}${suffix}.png" "$radius" "$margin"
done

cat > "$OUT/Contents.json" <<'EOF'
{
  "images" : [
    { "filename" : "icon-ios-1024.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" },
    { "filename" : "icon-mac-16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon-mac-16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon-mac-32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon-mac-32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon-mac-128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon-mac-128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon-mac-256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon-mac-256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon-mac-512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon-mac-512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
EOF

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

for layer in Front Middle Back; do
  lower="$(echo "$layer" | tr '[:upper:]' '[:lower:]')"
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
  swift "$SCRIPT_DIR/render_icon.swift" \
    "$REPO_ROOT/Resources/icon-vision-$lower.svg" \
    "$dir/Content.imageset/$layer.png" 1024
  echo "  $layer.solidimagestacklayer (1024px)"
done

# アプリ内表示用（About 画面など）。AppIcon.appiconset はコードから参照できないため、
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

echo "完了: $OUT, $VISION_OUT, $ARTWORK_OUT"
