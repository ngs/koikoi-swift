#!/usr/bin/env python3
"""旧 Koikoi のカード JPG から紙テクスチャを除去して PNG に書き出す。

紙は完全ニュートラル（彩度 0 付近）の明度 210–235 に分布しているため、
「彩度が低く（max-min <= SAT_MAX）かつ min(r,g,b) >= LUMA_MIN」の画素を
純白に飛ばす。絵柄のベタ色（彩度が高い）には影響しない。

Usage: pretrace_cards.py <input_dir> <output_dir>
"""

import sys
from pathlib import Path

import numpy as np
from PIL import Image

SAT_MAX = 12
LUMA_MIN = 195


def whiten_paper(src: Path, dst: Path) -> float:
    im = Image.open(src).convert("RGB")
    arr = np.asarray(im).astype(np.int16)
    mn = arr.min(axis=2)
    sat = arr.max(axis=2) - mn
    mask = (sat <= SAT_MAX) & (mn >= LUMA_MIN)
    arr[mask] = 255
    Image.fromarray(arr.astype(np.uint8)).save(dst)
    return float(mask.mean())


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        return 1
    input_dir = Path(sys.argv[1]).expanduser()
    output_dir = Path(sys.argv[2]).expanduser()
    output_dir.mkdir(parents=True, exist_ok=True)

    jpgs = sorted(input_dir.glob("*.jpg"))
    if not jpgs:
        print(f"no jpg files in {input_dir}", file=sys.stderr)
        return 1

    for src in jpgs:
        dst = output_dir / (src.stem + ".png")
        ratio = whiten_paper(src, dst)
        print(f"{src.name} -> {dst.name} (whitened {ratio:.1%})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
