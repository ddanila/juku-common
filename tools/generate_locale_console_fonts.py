#!/usr/bin/env python3
"""Generate compact Estonian and CP866 Russian Juku font banks."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path


CREEP_URL = "https://github.com/romeovs/creep/releases/download/0.31/creep.bdf"
CREEP_SHA256 = "747692a16464fa644f763f1891d43ab1712c598104cc4721c4338cb6ca6e7aa8"
CYRILLIC_URL = (
    "https://github.com/olikraus/u8g2/blob/"
    "ab9e48b2228351e9476682a70b7f3ee4909cd585/tools/font/bdf/4x6.bdf"
)
CYRILLIC_SHA256 = "cc8318b75a92f6209245ac771e891fa1b51a5c64e6eea0e0c85349eb89e8ef8b"

# ISO-8859-1 byte values make Estonian text interchangeable with ordinary
# host files. CP866 deliberately leaves B0h..DFh available for the existing
# edge-connected DOS/CP437 pseudographic vocabulary.
ESTONIAN = {
    0xC4: 0x00C4, 0xD5: 0x00D5, 0xD6: 0x00D6, 0xDC: 0x00DC,
    0xE4: 0x00E4, 0xF5: 0x00F5, 0xF6: 0x00F6, 0xFC: 0x00FC,
}
CP866 = {
    **{byte: 0x0410 + byte - 0x80 for byte in range(0x80, 0xA0)},
    **{byte: 0x0430 + byte - 0xA0 for byte in range(0xA0, 0xB0)},
    **{byte: 0x0440 + byte - 0xE0 for byte in range(0xE0, 0xF0)},
    0xF0: 0x0401,
    0xF1: 0x0451,
}

# Creep's uppercase accented forms are nine pixels tall. Preserve the accent
# and recognisable letter in the seven Juku text rows instead of clipping it.
COMPACT_OVERRIDES = {
    0x00C4: ("#.#..", ".##..", "#..#.", "####.", "#..#.", "#..#.", "#..#."),
    0x00D5: ("##.#.", ".##..", "#..#.", "#..#.", "#..#.", "#..#.", ".##.."),
    0x00D6: ("#.#..", ".##..", "#..#.", "#..#.", "#..#.", "#..#.", ".##.."),
    0x00DC: ("#.#..", "#..#.", "#..#.", "#..#.", "#..#.", "#..#.", ".###."),
    0x00F5: ("##.#.", ".....", ".##..", "#..#.", "#..#.", "#..#.", ".##.."),
}


def parse_bdf(path: Path, expected_sha256: str):
    data = path.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    if digest != expected_sha256:
        raise SystemExit(f"{path}: SHA-256 {digest} != expected {expected_sha256}")
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


def rows_for(glyphs, code: int) -> tuple[str, ...]:
    if code in COMPACT_OVERRIDES:
        return COMPACT_OVERRIDES[code]
    if code not in glyphs:
        raise ValueError(f"source has no U+{code:04X}")
    (width, height, xoff, yoff), source = glyphs[code]
    if width > 5 or height > 7:
        raise ValueError(f"U+{code:04X} has unsupported BBX {(width, height, xoff, yoff)}")
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


def encode(rows: tuple[str, ...]) -> list[int]:
    return [sum(0x80 >> x for x, pixel in enumerate(row) if pixel == "#")
            for row in rows]


def emit_bank(name: str, mapping: dict[int, int], glyphs, source: str,
              reference: list[str], assembly: list[str]) -> None:
    assembly.extend((f"RAMFONT{name}CODES:", "        db      " + ",".join(
        f"0{byte:02x}h" for byte in mapping), f"RAMFONT{name}:"))
    for byte, code in mapping.items():
        rows = rows_for(glyphs, code)
        reference.append(f"{name} {byte:02X} U+{code:04X} " + " ".join(rows))
        values = ",".join(f"0{value:02x}h" for value in encode(rows))
        assembly.append(f"        db      {values} ; {byte:02X} U+{code:04X}")
    assembly.append(f"RAMFONT{name}END:")
    assembly.append("")


def outputs(creep: Path, cyrillic: Path) -> tuple[str, str]:
    creep_glyphs = parse_bdf(creep, CREEP_SHA256)
    cyrillic_glyphs = parse_bdf(cyrillic, CYRILLIC_SHA256)
    reference = [
        "# Juku locale font-bank reference",
        f"# Estonian source: {CREEP_URL}",
        f"# Creep SHA-256: {CREEP_SHA256}",
        f"# Cyrillic source: {CYRILLIC_URL}",
        f"# Cyrillic BDF SHA-256: {CYRILLIC_SHA256}",
        "# Rows are five pixels wide and seven scanlines high.",
    ]
    assembly = [
        "; Generated compact locale font banks; do not edit by hand.",
        "; Estonian glyphs: MIT Creep 0.31; see LICENSE-CREEP.",
        "; Cyrillic glyphs: public-domain u8g2 4x6.bdf; see LICENSE-U8G2-4X6.",
        "",
    ]
    emit_bank("ESTONIAN", ESTONIAN, creep_glyphs, CREEP_URL,
              reference, assembly)
    emit_bank("CP866", CP866, cyrillic_glyphs, CYRILLIC_URL,
              reference, assembly)
    return "\n".join(reference) + "\n", "\n".join(assembly) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("creep", type=Path)
    parser.add_argument("cyrillic", type=Path)
    parser.add_argument("--reference", type=Path)
    parser.add_argument("--assembly", type=Path)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    reference, assembly = outputs(args.creep, args.cyrillic)
    for path, content in ((args.reference, reference), (args.assembly, assembly)):
        if path is None:
            continue
        if args.check:
            if path.read_text() != content:
                raise SystemExit(f"{path}: generated content differs")
        else:
            path.write_text(content)
    if args.check:
        print("Juku locale font generation: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
