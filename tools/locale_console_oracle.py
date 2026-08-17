#!/usr/bin/env python3
"""Check generated Juku locale banks, encodings, and separator geometry."""

from __future__ import annotations

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
REFERENCE = ROOT / "platform" / "locale-console-fonts-reference.txt"
ASSEMBLY = ROOT / "platform" / "locale-console-fonts.asm"
ESTONIAN = (0xC4, 0xD5, 0xD6, 0xDC, 0xE4, 0xF5, 0xF6, 0xFC)
CP866 = tuple(range(0x80, 0xB0)) + tuple(range(0xE0, 0xF2))


def reference() -> dict[tuple[str, int], tuple[str, ...]]:
    result = {}
    for number, raw in enumerate(REFERENCE.read_text().splitlines(), 1):
        if not raw or raw.startswith("#"):
            continue
        fields = raw.split()
        if len(fields) != 10 or not fields[2].startswith("U+"):
            raise ValueError(f"{REFERENCE}:{number}: malformed glyph")
        rows = tuple(fields[3:])
        if any(len(row) != 5 or set(row) - {".", "#"} for row in rows):
            raise ValueError(f"{REFERENCE}:{number}: invalid pixels")
        result[(fields[0], int(fields[1], 16))] = rows
    return result


def encoded(rows: tuple[str, ...]) -> bytes:
    return bytes(sum(0x80 >> x for x, pixel in enumerate(row) if pixel == "#")
                 for row in rows)


def section(text: str, start: str, end: str) -> bytes:
    body = text.split(start + ":", 1)[1].split(end + ":", 1)[0]
    return bytes(int(value, 16) for value in re.findall(
        r"\b0([0-9a-f]{2})h\b", body, re.IGNORECASE))


def main() -> int:
    glyphs = reference()
    if tuple(code for kind, code in glyphs if kind == "ESTONIAN") != ESTONIAN:
        raise SystemExit("Estonian ISO-8859-1 code order changed")
    if tuple(code for kind, code in glyphs if kind == "CP866") != CP866:
        raise SystemExit("Russian CP866 code order changed")
    text = ASSEMBLY.read_text()
    estonian = section(text, "RAMFONTESTONIAN", "RAMFONTESTONIANEND")
    russian = section(text, "RAMFONTCP866", "RAMFONTCP866END")
    if estonian != b"".join(encoded(glyphs[("ESTONIAN", code)])
                              for code in ESTONIAN):
        raise SystemExit("Estonian assembly differs from readable reference")
    if russian != b"".join(encoded(glyphs[("CP866", code)])
                             for code in CP866):
        raise SystemExit("CP866 assembly differs from readable reference")
    if set(CP866) & set(range(0xB0, 0xE0)):
        raise SystemExit("CP866 Cyrillic overlaps CP437 pseudographics")
    for key, rows in glyphs.items():
        if any(row[4] == "#" for row in rows):
            raise SystemExit(f"{key} occupies the separator column")
    print("Locale font oracle: PASS (8 Estonian + 66 CP866 Cyrillic glyphs)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
