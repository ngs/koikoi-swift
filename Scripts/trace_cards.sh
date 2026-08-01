#!/bin/bash
# 旧 Koikoi のカード JPG 48 枚を Illustrator の Image Trace で一括 SVG 化する。
# 実体は Scripts/trace_cards.jsx（入出力パスもそちらで設定）。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
JSX="$SCRIPT_DIR/trace_cards.jsx"
INPUT_DIR="$HOME/Library/CloudStorage/Dropbox/Codes/Koikoi/Assets/Sprites/Cards"
PRETRACE_DIR="/tmp/koikoi_pretrace"

if [ ! -f "$JSX" ]; then
  echo "trace_cards.jsx が見つかりません: $JSX" >&2
  exit 1
fi

echo "1/2: 紙テクスチャを除去した作業用 PNG を生成します..."
python3 "$SCRIPT_DIR/pretrace_cards.py" "$INPUT_DIR" "$PRETRACE_DIR"

echo "2/2: Adobe Illustrator で一括 Image Trace を実行します..."
echo "(48 枚で数分かかります。完了すると Illustrator 側にダイアログが出ます)"

osascript <<EOF
tell application id "com.adobe.illustrator"
  activate
  do javascript (POSIX file "$JSX" as alias)
end tell
EOF

echo "完了。出力: ~/src/koikoi-swift/Assets/cards/traced/ (trace_log.txt 参照)"
