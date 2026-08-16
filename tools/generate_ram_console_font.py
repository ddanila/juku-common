#!/usr/bin/env python3
"""Convert domsson's CC0 5x7 sprite sheet to Juku scanline bytes."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

from PIL import Image


SOURCE_URL = (
    "https://opengameart.org/sites/default/files/"
    "charmap-oldschool_white.png"
)
SOURCE_SHA256 = "cf7d942a052f451a2bd24e02f193ea96433eeceeb705c8b0b2d2296f3ce57708"
FIRST = 0x20
LAST = 0x7E
SHEET_COLUMNS = 18
CELL_WIDTH = 7
# The sprite sheet leaves one empty separator row between each 8-pixel cell.
# Its six glyph rows therefore start at y=1,10,19,28,37,46: a 9-pixel pitch.
# Treating the pitch as 8 made every row after the first drift upward and
# produced deterministic, increasingly corrupted glyphs.
CELL_HEIGHT = 9
GLYPH_X = 1
GLYPH_Y = 1
GLYPH_WIDTH = 5
GLYPH_HEIGHT = 7


def convert(source: Path) -> str:
    data = source.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    if digest != SOURCE_SHA256:
        raise SystemExit(
            f"{source}: SHA-256 {digest} != expected {SOURCE_SHA256}"
        )
    image = Image.open(source).convert("1")
    if image.size != (128, 64):
        raise SystemExit(f"{source}: size {image.size} != expected 128x64")

    lines = [
        "; U+0020..U+007E, five MSB-first pixels by seven scanlines.",
        "; domsson's oldschool font, CC0-1.0:",
        "; https://opengameart.org/content/ascii-bitmap-font-oldschool",
        f"; source PNG SHA-256: {SOURCE_SHA256}",
        "RAMFONT:",
    ]
    for code in range(FIRST, LAST + 1):
        index = code - FIRST
        x0 = (index % SHEET_COLUMNS) * CELL_WIDTH + GLYPH_X
        y0 = (index // SHEET_COLUMNS) * CELL_HEIGHT + GLYPH_Y
        rows = []
        for y in range(GLYPH_HEIGHT):
            value = 0
            for x in range(GLYPH_WIDTH):
                if image.getpixel((x0 + x, y0 + y)):
                    value |= 0x80 >> x
            rows.append(value)
        printable = chr(code) if code not in (0x20, 0x27, 0x5C) else {
            0x20: "space",
            0x27: "apostrophe",
            0x5C: "backslash",
        }[code]
        encoded = ",".join(f"0{value:02x}h" for value in rows)
        lines.append(f"        db      {encoded} ; {code:02X} {printable}")
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="downloaded CC0 PNG")
    parser.add_argument(
        "--check", type=Path,
        help="compare generated output with an existing assembler file",
    )
    args = parser.parse_args()
    output = convert(args.source)
    if args.check:
        current = args.check.read_text()
        if current != output:
            raise SystemExit(f"{args.check}: generated font differs")
        print(f"{args.check}: PASS")
    else:
        print(output, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
