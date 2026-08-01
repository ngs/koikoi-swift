#!/bin/bash
# 旧 Koikoi のカード JPG 48 枚を「前処理 → Illustrator Image Trace →
# Resources/Assets.xcassets/Cards への反映」まで一括で行う。
# 中間生成物（前処理 PNG・トレース済み SVG）は /tmp に置き、コミットしない。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
JSX="$SCRIPT_DIR/trace_cards.jsx"
# 旧 Koikoi の原画ディレクトリ（KOIKOI_SPRITES_DIR で上書き可）
INPUT_DIR="${KOIKOI_SPRITES_DIR:-$HOME/Library/CloudStorage/Dropbox/Codes/Koikoi/Assets/Sprites/Cards}"
PRETRACE_DIR="/tmp/koikoi_pretrace"
TRACED_DIR="/tmp/koikoi_traced"

if [ ! -f "$JSX" ]; then
  echo "trace_cards.jsx が見つかりません: $JSX" >&2
  exit 1
fi

echo "1/3: 紙テクスチャを除去した作業用 PNG を生成します..."
python3 "$SCRIPT_DIR/pretrace_cards.py" "$INPUT_DIR" "$PRETRACE_DIR"

echo "2/3: Adobe Illustrator で一括 Image Trace を実行します..."
echo "(48 枚で数分かかります。完了すると Illustrator 側にダイアログが出ます)"

osascript <<EOF
tell application id "com.adobe.illustrator"
  activate
  do javascript (POSIX file "$JSX" as alias)
end tell
EOF

echo "3/3: xcassets へ反映します..."
"$SCRIPT_DIR/cards_to_xcassets.sh" "$TRACED_DIR"

echo "完了。(トレースのログ: $TRACED_DIR/trace_log.txt)"
