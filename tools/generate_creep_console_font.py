#!/usr/bin/env python3
"""Adapt Creep ASCII and CP437 pseudographics to Juku's 5x8 cell."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path


SOURCE_URL = "https://github.com/romeovs/creep/releases/download/0.31/creep.bdf"
SOURCE_SHA256 = "747692a16464fa644f763f1891d43ab1712c598104cc4721c4338cb6ca6e7aa8"
FIRST = 0x20
LAST = 0x7E
PSEUDO_CODES = (
    0xB0, 0xB3, 0xB4, 0xB6, 0xBA, 0xBB, 0xBC, 0xBF,
    0xC0, 0xC1, 0xC2, 0xC3, 0xC4, 0xC5, 0xC7, 0xC8,
    0xC9, 0xCD, 0xD1, 0xD9, 0xDA, 0xDB, 0xDC, 0xDD,
    0xDE, 0xDF,
)

# Creep's terminal metrics permit glyphs taller than our raster cell. These
# compact replacements retain the same four-pixel visual vocabulary while
# fitting exactly seven text scanlines.
OVERRIDES = {
    0x28: ("..#..", ".#...", "#....", "#....", "#....", ".#...", "..#.."),
    0x29: (".#...", "..#..", "...#.", "...#.", "...#.", "..#..", ".#..."),
    0x2F: ("...#.", "...#.", "..#..", "..#..", ".#...", ".#...", "#...."),
    0x51: (".##..", "#..#.", "#..#.", "#..#.", "#..#.", ".###.", "...#."),
    0x5B: (".##..", ".#...", ".#...", ".#...", ".#...", ".#...", ".##.."),
    0x5C: ("#....", "#....", ".#...", ".#...", "..#..", "..#..", "...#."),
    0x5D: (".##..", "..#..", "..#..", "..#..", "..#..", "..#..", ".##.."),
    0x66: ("..#..", ".#.#.", ".#...", "###..", ".#...", ".#...", ".#..."),
    0x6A: ("..#..", ".....", ".##..", "..#..", "..#..", "..#..", ".#..."),
    0x7B: ("..##.", ".#...", ".#...", "#....", ".#...", ".#...", "..##."),
    0x7D: ("##...", "..#..", "..#..", "...#.", "..#..", "..#..", "##..."),
}

# CP437 B0h..DAh box topology. Each tuple is left, up, right, down; 1 is a
# single stroke and 2 a double stroke. DBh..DFh are block elements below.
BOX = {
    0xB3: (0, 1, 0, 1), 0xB4: (1, 1, 0, 1),
    0xB5: (2, 1, 0, 1), 0xB6: (1, 2, 0, 2),
    0xB7: (2, 0, 0, 1), 0xB8: (1, 0, 0, 2),
    0xB9: (2, 2, 0, 2), 0xBA: (0, 2, 0, 2),
    0xBB: (2, 0, 0, 2), 0xBC: (2, 2, 0, 0),
    0xBD: (1, 2, 0, 0), 0xBE: (2, 1, 0, 0),
    0xBF: (1, 0, 0, 1), 0xC0: (0, 1, 1, 0),
    0xC1: (1, 1, 1, 0), 0xC2: (1, 0, 1, 1),
    0xC3: (0, 1, 1, 1), 0xC4: (1, 0, 1, 0),
    0xC5: (1, 1, 1, 1), 0xC6: (0, 1, 2, 1),
    0xC7: (0, 2, 1, 2), 0xC8: (0, 2, 2, 0),
    0xC9: (0, 0, 2, 2), 0xCA: (2, 2, 2, 0),
    0xCB: (2, 0, 2, 2), 0xCC: (0, 2, 2, 2),
    0xCD: (2, 0, 2, 0), 0xCE: (2, 2, 2, 2),
    0xCF: (2, 1, 2, 0), 0xD0: (1, 2, 1, 0),
    0xD1: (2, 0, 2, 1), 0xD2: (1, 0, 1, 2),
    0xD3: (0, 1, 2, 0), 0xD4: (0, 2, 1, 0),
    0xD5: (0, 0, 2, 1), 0xD6: (0, 0, 1, 2),
    0xD7: (2, 1, 2, 1), 0xD8: (1, 2, 1, 2),
    0xD9: (1, 1, 0, 0), 0xDA: (0, 0, 1, 1),
}


def parse_bdf(source: Path) -> dict[int, tuple[tuple[int, int, int, int], list[int]]]:
    data = source.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    if digest != SOURCE_SHA256:
        raise SystemExit(f"{source}: SHA-256 {digest} != expected {SOURCE_SHA256}")
    lines = data.decode("ascii").splitlines()
    glyphs = {}
    index = 0
    while index < len(lines):
        if not lines[index].startswith("STARTCHAR "):
            index += 1
            continue
        code = -1
        box = None
        rows = []
        index += 1
        while lines[index] != "ENDCHAR":
            fields = lines[index].split()
            if fields[0] == "ENCODING":
                code = int(fields[1])
            elif fields[0] == "BBX":
                box = tuple(map(int, fields[1:5]))
            elif fields[0] == "BITMAP":
                index += 1
                while lines[index] != "ENDCHAR":
                    rows.append(int(lines[index], 16))
                    index += 1
                break
            index += 1
        if code >= 0 and box is not None:
            glyphs[code] = (box, rows)
        index += 1
    return glyphs


def ascii_rows(glyphs, code: int) -> tuple[str, ...]:
    if code in OVERRIDES:
        return OVERRIDES[code]
    (width, height, xoff, yoff), source = glyphs[code]
    if width > 5 or height > 7:
        raise ValueError(f"U+{code:04X} has unsupported BBX {width,height,xoff,yoff}")
    # Preserve normal baseline placement. Descenders are shifted upward as a
    # unit so all of their distinguishing pixels survive the seven-row cell.
    shift = -yoff if yoff < 0 else 0
    canvas = [[False] * 5 for _ in range(7)]
    for source_y, value in enumerate(source):
        ycoord = yoff + height - 1 - source_y + shift
        target_y = 6 - ycoord
        if not 0 <= target_y < 7:
            continue
        for source_x in range(width):
            target_x = xoff + source_x
            if 0 <= target_x < 5 and value & (0x80 >> source_x):
                canvas[target_y][target_x] = True
    return tuple("".join("#" if pixel else "." for pixel in row)
                 for row in canvas)


def box_rows(sides: tuple[int, int, int, int]) -> tuple[str, ...]:
    left, up, right, down = sides
    pixels = [[False] * 5 for _ in range(8)]

    def horizontal(kind: int, start: int, stop: int) -> None:
        for y in ((3,) if kind == 1 else (2, 4)):
            for x in range(start, stop):
                pixels[y][x] = True

    def vertical(kind: int, start: int, stop: int) -> None:
        for x in ((2,) if kind == 1 else (1, 3)):
            for y in range(start, stop):
                pixels[y][x] = True

    if left: horizontal(left, 0, 3)
    if right: horizontal(right, 2, 5)
    if up: vertical(up, 0, 4)
    if down: vertical(down, 3, 8)
    return tuple("".join("#" if pixel else "." for pixel in row)
                 for row in pixels)


def pseudo_rows(code: int) -> tuple[str, ...]:
    if code == 0xB0:
        return tuple("#...." if y % 3 == 0 else "...#." if y % 3 == 1 else "....."
                     for y in range(8))
    if code == 0xB1:
        return tuple("#.#.#" if y % 2 == 0 else ".#.#." for y in range(8))
    if code == 0xB2:
        return tuple("#####" if y % 3 else ".###." for y in range(8))
    if code in BOX:
        return box_rows(BOX[code])
    if code == 0xDB: return ("#####",) * 8
    if code == 0xDC: return (".....",) * 4 + ("#####",) * 4
    if code == 0xDD: return ("###..",) * 8
    if code == 0xDE: return ("..###",) * 8
    if code == 0xDF: return ("#####",) * 4 + (".....",) * 4
    raise ValueError(f"unsupported CP437 code {code:02X}")


def encode(rows: tuple[str, ...]) -> list[int]:
    return [sum(0x80 >> x for x, pixel in enumerate(row) if pixel == "#")
            for row in rows]


def outputs(source: Path) -> tuple[str, str]:
    glyphs = parse_bdf(source)
    reference = [
        "# Creep-derived Juku 5x8 reference",
        f"# Source: {SOURCE_URL}",
        f"# BDF SHA-256: {SOURCE_SHA256}",
        "# ASCII has seven rows; the CP437 UI subset has all eight cell rows.",
    ]
    assembly = [
        "; Creep-derived U+0020..U+007E, adapted to five by seven pixels.",
        "; MIT license: LICENSE-CREEP; Copyright (c) 2014 Romeo Van Snick.",
        f"; release BDF SHA-256: {SOURCE_SHA256}",
        ".ifndef CREEP_PSEUDO_ONLY",
        "RAMFONT80:",
    ]
    for code in range(FIRST, LAST + 1):
        rows = ascii_rows(glyphs, code)
        reference.append(f"{code:02X} " + " ".join(rows))
        values = ",".join(f"0{value:02x}h" for value in encode(rows))
        assembly.append(f"        db      {values} ; {code:02X}")
    assembly.extend([
        ".endif",
        "",
        "; CP437 UI subset: shade, VC-compatible boxes, and blocks.",
        ".ifndef CREEP_ASCII_ONLY",
        "CREEP_INCLUDE_PSEUDO equ 1",
        ".endif",
        ".ifdef CREEP_PSEUDO_ONLY",
        "CREEP_INCLUDE_PSEUDO equ 1",
        ".endif",
        ".ifdef CREEP_INCLUDE_PSEUDO",
        "RAMFONTPSEUDOCODES:",
        "        db      " + ",".join(f"0{code:02x}h" for code in PSEUDO_CODES),
        "RAMFONTPSEUDO:",
    ])
    for code in PSEUDO_CODES:
        rows = pseudo_rows(code)
        reference.append(f"{code:02X} " + " ".join(rows))
        values = ",".join(f"0{value:02x}h" for value in encode(rows))
        assembly.append(f"        db      {values} ; {code:02X}")
    assembly.append(".endif")
    return "\n".join(reference) + "\n", "\n".join(assembly) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--reference", type=Path)
    parser.add_argument("--assembly", type=Path)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    reference, assembly = outputs(args.source)
    for path, content in ((args.reference, reference), (args.assembly, assembly)):
        if path is None:
            continue
        if args.check:
            if path.read_text() != content:
                raise SystemExit(f"{path}: generated content differs")
        else:
            path.write_text(content)
    if args.check:
        print("Creep Juku font generation: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
