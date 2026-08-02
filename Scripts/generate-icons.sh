#!/bin/bash
# Resources/icon-template.svg から AppIcon.appiconset を生成する。
# レンダリングは Scripts/render_icon.swift（AppKit）で行う（macOS 標準ツールのみ使用）。
# macOS アイコンは Apple 流儀（約 10% マージン + 角丸）を適用する。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SVG="$REPO_ROOT/Resources/icon-template.svg"
OUT="$REPO_ROOT/Resources/Assets.xcassets/AppIcon.appiconset"

mkdir -p "$OUT"

render() { # px out radius margin
  swift "$SCRIPT_DIR/render_icon.swift" "$SVG" "$OUT/$2" "$1" "${3:-0}" "${4:-0}"
  echo "  $2 (${1}px)"
}

echo "iOS/visionOS 用 (フルブリード):"
render 1024 icon-ios-1024.png

echo "macOS 用 (マージン + 角丸):"
for entry in 16:1 16:2 32:1 32:2 128:1 128:2 256:1 256:2 512:1 512:2; do
  size="${entry%%:*}"; scale="${entry##*:}"
  px=$((size * scale))
  margin=$(awk "BEGIN { print $px * 0.098 }")
  radius=$(awk "BEGIN { print ($px - 2 * $px * 0.098) * 0.2237 }")
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

echo "完了: $OUT"
