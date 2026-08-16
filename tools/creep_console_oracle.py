#!/usr/bin/env python3
"""Independent structural checks for the adapted Creep/Juku font."""

from __future__ import annotations

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
REFERENCE = ROOT / "platform" / "creep-console-font-reference.txt"
ASSEMBLY = ROOT / "platform" / "creep-console-font.asm"
PSEUDO = (0xB0, 0xB3, 0xB4, 0xBF, 0xC0, 0xC1, 0xC2, 0xC3,
          0xC4, 0xC5, 0xD9, 0xDA, 0xDB, 0xDC, 0xDD, 0xDE, 0xDF)


def load_reference() -> dict[int, tuple[str, ...]]:
    result = {}
    for number, raw in enumerate(REFERENCE.read_text().splitlines(), 1):
        if not raw or raw.startswith("#"):
            continue
        fields = raw.split()
        code = int(fields[0], 16)
        expected = 7 if 0x20 <= code <= 0x7E else 8
        if len(fields) != expected + 1:
            raise ValueError(f"{REFERENCE}:{number}: expected {expected} rows")
        if any(len(row) != 5 or set(row) - {".", "#"} for row in fields[1:]):
            raise ValueError(f"{REFERENCE}:{number}: invalid pixel row")
        result[code] = tuple(fields[1:])
    if sorted(code for code in result if code < 0x80) != list(range(0x20, 0x7F)):
        raise ValueError("ASCII reference is incomplete")
    if tuple(code for code in result if code >= 0x80) != PSEUDO:
        raise ValueError("CP437 UI subset/order changed")
    return result


def assembly_bytes() -> tuple[bytes, bytes, bytes]:
    text = ASSEMBLY.read_text()
    sections = re.split(r"^RAMFONT(?:80|PSEUDOCODES|PSEUDO):\s*$", text,
                        flags=re.MULTILINE)
    if len(sections) != 4:
        raise ValueError("expected three font labels")
    parsed = []
    for section in sections[1:]:
        parsed.append(bytes(int(value, 16) for value in re.findall(
            r"\b0([0-9a-f]{2})h\b", section, re.IGNORECASE)))
    return tuple(parsed)


def encoded(rows: tuple[str, ...]) -> bytes:
    return bytes(sum(0x80 >> x for x, pixel in enumerate(row) if pixel == "#")
                 for row in rows)


VIDEO_MODES = {
    0: (40, 24, 8, 10, 40),
    1: (53, 24, 6, 10, 40),
    2: (64, 20, 6, 10, 48),
    3: (80, 24, 5, 8, 50),
}


def render_transcript(transcript: bytes, *, cursor: bool = True,
                      mode: int = 3) -> bytes:
    """Render one DIP-selected mode independently from the 8080 routine."""
    reference = load_reference()
    columns, rows, cell_width, cell_height, stride = VIDEO_MODES[mode]
    row_bytes = stride * cell_height
    framebuffer = bytearray(9600)
    column = row = 0
    escaped = False

    def paint(cell_row: int, cell_column: int, glyph: tuple[str, ...],
              *, cursor_cell: bool = False) -> None:
        if cursor_cell:
            scanlines = (("#" * cell_width,)
                         if cell_height == 1 else
                         (("." * cell_width,) * (cell_height - 1) +
                          ("#" * cell_width,)))
        else:
            scanlines = tuple(row.ljust(cell_width, ".") for row in glyph)
            scanlines += (("." * cell_width,) *
                          (cell_height - len(scanlines)))
        for scanline, pixels in enumerate(scanlines):
            y = cell_row * cell_height + scanline
            for x, pixel in enumerate(pixels):
                offset = y * stride + (cell_column * cell_width + x) // 8
                mask = 0x80 >> ((cell_column * cell_width + x) & 7)
                if pixel == "#": framebuffer[offset] |= mask
                else: framebuffer[offset] &= ~mask

    for character in transcript:
        if escaped:
            escaped = False
            if character == ord("L"):
                framebuffer[:] = bytes(len(framebuffer))
                column = row = 0
            continue
        if character == 0x1B:
            escaped = True
        elif character == 0x0D:
            column = 0
        elif character == 0x0A:
            row += 1
        elif character == 0x08:
            column = max(0, column - 1)
        elif character >= 0x20:
            glyph = (reference.get(character, reference[ord("?")])
                     if character < 0x7F or mode == 3
                     else reference[ord("?")])
            paint(row, column, glyph)
            column += 1
            if column == columns:
                column = 0
                row += 1
        if row >= rows:
            framebuffer[:-row_bytes] = framebuffer[row_bytes:]
            framebuffer[-row_bytes:] = bytes(row_bytes)
            row = rows - 1
    if cursor:
        paint(row, column, (), cursor_cell=True)
    return bytes(framebuffer)


def main() -> int:
    reference = load_reference()
    ascii_table, codes, pseudo_table = assembly_bytes()
    expected_ascii = b"".join(encoded(reference[code])
                              for code in range(0x20, 0x7F))
    expected_pseudo = b"".join(encoded(reference[code]) for code in PSEUDO)
    if ascii_table != expected_ascii or codes != bytes(PSEUDO) or \
            pseudo_table != expected_pseudo:
        raise SystemExit("generated assembly differs from readable reference")

    # Ordinary letters and digits retain a guaranteed blank right edge, so
    # any repeated or adjacent pair still has a visible inter-cell separator.
    for code in list(range(ord("0"), ord("9") + 1)) + \
            list(range(ord("A"), ord("Z") + 1)) + \
            list(range(ord("a"), ord("z") + 1)):
        if any(row[4] == "#" for row in reference[code]):
            raise SystemExit(f"U+{code:04X} occupies its separator column")

    # Repeated horizontal/vertical strokes are byte-exact solid connections.
    if reference[0xC4][3] != "#####" or \
            any(row != "..#.." for row in reference[0xB3]):
        raise SystemExit("single box strokes do not span the complete cell")
    for code in (0xB4, 0xBF, 0xC0, 0xC1, 0xC2, 0xC3,
                 0xC5, 0xD9, 0xDA):
        rows = reference[code]
        if not (any(row[0] == "#" for row in rows) or
                any(row[4] == "#" for row in rows) or
                rows[0][2] == "#" or rows[-1][2] == "#"):
            raise SystemExit(f"CP437 {code:02X} has no connecting edge")
    if any(row != "#####" for row in reference[0xDB]):
        raise SystemExit("full block is not five by eight")
    # Cell repetition is the critical text-UI property: horizontal strokes
    # reach both five-pixel sides and vertical strokes reach both scan edges.
    if reference[0xC4] != (".....", ".....", ".....", "#####",
                           ".....", ".....", ".....", "....."):
        raise SystemExit("repeated CP437 C4 cells cannot form a solid line")
    if reference[0xB3][0][2] != "#" or reference[0xB3][-1][2] != "#":
        raise SystemExit("stacked CP437 B3 cells cannot form a solid line")
    print("Creep console oracle: PASS (95 text + 17 CP437 UI glyphs)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
