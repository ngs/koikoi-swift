#!/bin/bash
# Assets/cards/traced/*.svg をアプリの Assets.xcassets 内 Cards フォルダに変換する。
# 各札は preserves-vector-representation 付きの imageset になる（SVG のまま保持）。
# Cards フォルダだけを再生成し、AccentColor 等の他アセットには触れない。
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$REPO_ROOT/Assets/cards/traced"
XCASSETS="$REPO_ROOT/Resources/Assets.xcassets/Cards"

if [ ! -d "$SRC_DIR" ]; then
  echo "traced SVG がありません: $SRC_DIR (先に Scripts/trace_cards.sh を実行)" >&2
  exit 1
fi

count=$(find "$SRC_DIR" -name '*.svg' | wc -l | tr -d ' ')
if [ "$count" -ne 48 ]; then
  echo "SVG が 48 枚ありません ($count 枚): $SRC_DIR" >&2
  exit 1
fi

rm -rf "$XCASSETS"
mkdir -p "$XCASSETS"

# フォルダはグルーピングのみ（名前空間は付けない = アセット名はフラット）
cat > "$XCASSETS/Contents.json" <<'EOF'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

for svg in "$SRC_DIR"/*.svg; do
  name="$(basename "$svg" .svg)"
  imageset="$XCASSETS/$name.imageset"
  mkdir -p "$imageset"
  cp "$svg" "$imageset/$name.svg"
  cat > "$imageset/Contents.json" <<EOF
{
  "images" : [
    {
      "filename" : "$name.svg",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "preserves-vector-representation" : true
  }
}
EOF
done

echo "生成完了: $XCASSETS ($count imagesets)"
