#!/usr/bin/env python3
"""検証用 HTML を PNG にする。375px ははみ出しが見えるよう frame 付きで撮る。"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from PIL import Image

CHROME = "google-chrome"
ROOT = Path(__file__).resolve().parents[2]
EXAMPLES = ROOT / "examples"
OUT = Path(__file__).resolve().parent

# (html, query, outfile, window_w, window_h)
JOBS = [
    ("repro-before.html", "frame=375", "before-375.png", 1280, 2000),
    ("repro-after.html", "frame=375", "after-375.png", 1280, 2000),
    ("repro-before.html", "", "before-1280.png", 1280, 1600),
    ("repro-after.html", "", "after-1280.png", 1280, 1600),
]


def render(html: Path, query: str, png: Path, w: int, h: int) -> None:
    uri = html.resolve().as_uri()
    if query:
        uri += "?" + query
    cmd = [
        CHROME,
        "--headless=new",
        "--disable-gpu",
        "--no-sandbox",
        "--force-device-scale-factor=1",
        f"--window-size={w},{h}",
        "--virtual-time-budget=4000",
        f"--screenshot={png}",
        uri,
    ]
    subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    crop_whitespace(png)
    print(f"wrote {png}")


def _is_empty_pixel(rgb: tuple[int, int, int]) -> bool:
    r, g, b = rgb
    if r > 250 and g > 250 and b > 250:
        return True
    # 検証ページの背景 #f6f6f6
    return abs(r - 246) <= 3 and abs(g - 246) <= 3 and abs(b - 246) <= 3


def crop_whitespace(path: Path, pad: int = 12) -> None:
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    last = 0
    for y in range(h):
        empty = True
        for x in range(0, w, 2):
            if not _is_empty_pixel(px[x, y]):
                empty = False
                break
        if not empty:
            last = y
    box = (0, 0, w, min(h, last + 1 + pad))
    im.crop(box).save(path, optimize=True)
    print(f"  cropped {w}x{h} -> {box[2]-box[0]}x{box[3]-box[1]}")


def main() -> int:
    for name, query, out, w, h in JOBS:
        render(EXAMPLES / name, query, OUT / out, w, h)
    return 0


if __name__ == "__main__":
    sys.exit(main())
