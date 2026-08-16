#!/usr/bin/env python3
"""Independent source-font oracle for the Juku MODX 80x24 console."""

from __future__ import annotations

import argparse
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
REFERENCE = ROOT / "platform" / "ram-console-font-reference.txt"
ASSEMBLY = ROOT / "platform" / "ram-console-font.asm"
FIRST = 0x20
LAST = 0x7E
WIDTH = 400
HEIGHT = 192
STRIDE = WIDTH // 8


def load_reference(path: Path = REFERENCE) -> bytes:
    """Read the human-reviewable 5x7 source glyphs into MSB-first rows."""
    glyphs: dict[int, bytes] = {}
    for number, raw in enumerate(path.read_text().splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        fields = line.split()
        if len(fields) != 8:
            raise ValueError(f"{path}:{number}: expected code plus seven rows")
        code = int(fields[0], 16)
        if code in glyphs:
            raise ValueError(f"{path}:{number}: duplicate code {code:02X}")
        rows = bytearray()
        for row in fields[1:]:
            if len(row) != 5 or set(row) - {".", "#"}:
                raise ValueError(f"{path}:{number}: invalid row {row!r}")
            value = sum(0x80 >> bit for bit, pixel in enumerate(row)
                        if pixel == "#")
            rows.append(value)
        glyphs[code] = bytes(rows)
    expected = list(range(FIRST, LAST + 1))
    if sorted(glyphs) != expected:
        raise ValueError(f"{path}: expected U+0020..U+007E exactly")
    return b"".join(glyphs[code] for code in expected)


def load_assembly(path: Path = ASSEMBLY) -> bytes:
    """Parse the generated assembler table without using its generator."""
    result = bytearray()
    for line in path.read_text().splitlines():
        if not line.lstrip().lower().startswith("db "):
            continue
        result.extend(int(value, 16) for value in re.findall(
            r"\b([0-9a-f]+)h\b", line, re.IGNORECASE,
        ))
    if len(result) != (LAST - FIRST + 1) * 7:
        raise ValueError(f"{path}: got {len(result)} bytes, expected 665")
    return bytes(result)


def render_transcript(transcript: bytes, *, font: bytes | None = None,
                      cursor: bool = True) -> bytes:
    """Render console bytes by individual pixels, independently of 8080 code."""
    source = font if font is not None else load_reference()
    if len(source) != (LAST - FIRST + 1) * 7:
        raise ValueError("font must contain 95 seven-row glyphs")
    framebuffer = bytearray(STRIDE * HEIGHT)
    column = row = 0
    escaped = False

    def paint(cell_row: int, cell_column: int, scanlines: bytes) -> None:
        if not 0 <= cell_row < 24 or not 0 <= cell_column < 80:
            raise ValueError(f"cell outside screen: {cell_column},{cell_row}")
        if len(scanlines) != 8:
            raise ValueError("cell must have eight scanlines")
        for scanline, pixels in enumerate(scanlines):
            y = cell_row * 8 + scanline
            for x in range(5):
                pixel = cell_column * 5 + x
                offset = y * STRIDE + pixel // 8
                mask = 0x80 >> (pixel & 7)
                if pixels & (0x80 >> x):
                    framebuffer[offset] |= mask
                else:
                    framebuffer[offset] &= ~mask

    for character in transcript:
        if escaped:
            escaped = False
            if character == ord("L"):
                framebuffer[:] = bytes(len(framebuffer))
                column = row = 0
            continue
        if character == 0x1B:
            escaped = True
            continue
        if character == 0x0D:
            column = 0
            continue
        if character == 0x0A:
            row += 1
        elif character == 0x08:
            column = max(0, column - 1)
            continue
        elif character < FIRST:
            continue
        else:
            if character > LAST:
                character = ord("?")
            start = (character - FIRST) * 7
            paint(row, column, source[start:start + 7] + b"\0")
            column += 1
            if column < 80:
                continue
            column = 0
            row += 1
        if row >= 24:
            framebuffer[:9200] = framebuffer[400:]
            framebuffer[9200:] = bytes(400)
            row = 23

    if cursor:
        paint(row, column, b"\0" * 7 + b"\xF8")
    return bytes(framebuffer)


def write_pbm(path: Path, framebuffer: bytes) -> None:
    if len(framebuffer) != STRIDE * HEIGHT:
        raise ValueError("framebuffer must be exactly 9,600 bytes")
    path.write_bytes(f"P4\n{WIDTH} {HEIGHT}\n".encode() + framebuffer)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--assembly", type=Path, default=ASSEMBLY)
    parser.add_argument("--render-text")
    parser.add_argument("--framebuffer", type=Path)
    parser.add_argument("--pbm", type=Path)
    args = parser.parse_args()
    reference = load_reference()
    generated = load_assembly(args.assembly)
    if generated != reference:
        first = next(i for i, pair in enumerate(zip(generated, reference))
                     if pair[0] != pair[1])
        code = FIRST + first // 7
        row = first % 7
        raise SystemExit(
            f"{args.assembly}: font differs at U+{code:04X} row {row}: "
            f"{generated[first]:02X} != {reference[first]:02X}"
        )
    if args.render_text is not None:
        framebuffer = render_transcript(args.render_text.encode("ascii"))
        if args.framebuffer:
            args.framebuffer.write_bytes(framebuffer)
        if args.pbm:
            write_pbm(args.pbm, framebuffer)
    elif args.framebuffer or args.pbm:
        parser.error("--framebuffer/--pbm require --render-text")
    print("RAM console source-font oracle: PASS (95 glyphs, 665 rows)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
