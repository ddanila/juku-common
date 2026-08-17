# Juku platform modules

These strict-8080 modules are shared by the CP/Mish Juku port and the separate
CP/M Plus Juku port:

- `ram-console.asm`: DIP-selectable 40x24, 53x24, 64x20, or MODX-compatible
  80x24 framebuffer console with a blinking underline cursor;
- `creep-console-font.asm`: Romeo Van Snick's MIT-licensed Creep font adapted
  to a five-by-seven Juku text cell, plus a compact standard-CP437 UI subset;
- `creep-console-font-reference.txt`: human-reviewable glyph rows used by an
  independent framebuffer oracle, not generated assembler;
- `locale-console-fonts.asm` and its reference: compact ISO-8859-1 Estonian
  and CP866 Russian extension banks. CP866 deliberately leaves B0h..DFh to
  the edge-connected CP437 text-interface glyphs;
- `ram-console-font.asm` and its reference: the earlier domsson CC0 5x7
  source, retained for historical comparison and possible wider modes;
- `ram-keyboard.asm`: interrupt-independent matrix keyboard driver; defining
  `ROMKEYBOARD` plus `ROMKEYSTATEBASE` reuses the same code/tables in resident
  ROM while keeping its three mutable bytes in low RAM; `RKCONFIG` returns the
  raw eight-position S21 configuration byte;
- `netdisk-v3.asm`: resilient three-record Janet read-ahead client;
- `netconsole.asm`: optional resilient remote console;
- `rom-abi.inc`: fixed network-first ROM manifest, feature, vector, and
  low-RAM ownership constants;
- `rom-call-gate.asm`: signature/version-checking low-RAM dispatcher for the
  fixed `FF20h+` service vectors.
- `rom-console-state.inc` and `rom-console-helper.asm`: fixed console workspace
  plus the copied clear/scroll/packed-row primitive that alone enters mode 3;

Consumers own their BIOS vectors, memory map, initialization policy, and disk
geometry. The assembly-time `CPM3ADAPTER` selection currently preserves the
two already-qualified workspace layouts while the CP/M Plus port replaces its
compatibility adapter with a native CP/M 3 hardware layer.

`netconsole.asm` multiplexes local-authoritative console traffic over the
same half-duplex USART as NetDisk. A negotiated N4 consumer calls `NCENA`
after consuming the capability marker; a direct network-first consumer may
arm it unconditionally because an unsupported request fails back to local
console operation. Each character or idle input poll is a
bounded request/reply turn; a failed host disables the remote path without
blocking the local screen or keyboard, and later status calls reprobe it.
After a remote byte is consumed, the next status call polls immediately so a
command burst is not delayed by the normal idle floor. Consumers whose local
status scan is itself slow may assemble with `NETCONSOLE_EAGER_POLL`; this
uses one bounded remote poll per idle status call while leaving the default
64-call floor unchanged. Its
128-iteration transmit drain is the same physical-CS00015-qualified
turnaround used by NetDisk v3. A longer 400-iteration drain loses the start of
a reply sent after the host's 2 ms guard at 19,200 baud.

Defining `NATIVE_SERVICES` adds the optional NetDisk-v3 service transports.
`NCTIME`
implements the CP/M Plus GET/SET clock contract without changing the host OS
clock. `NCPUBLISH` sends one idempotent status tuple (raw S21, decoded video
mode, feature flags, and last clock result) so target and host diagnostics
report the same configuration without adding unsolicited boot traffic.
`NCDIAG` uses the same preserved-register and bounded-turn contract for a
suite/pass/fail/flags result, allowing unattended diagnostics without a raw
USART owner or a disk-starving stream.
`NCCAPS` performs an explicit, repeatable operation-26h query and returns the
host's four-byte NetDisk protocol, maximum read-ahead, feature, and drive-count
record. This is the runtime contract; the earlier N3/N4 startup marker remains
only a synchronization hint. A native consumer passes the returned feature
byte to `NCCFG`: an explicit no-console result disables otherwise pointless
periodic N4 reprobes, while rejection by an older host retains the bounded
legacy discovery behavior.
The native profile also keeps saturating reconnect and last-failure fields at
C65Ch/C65Dh in its documented workspace. They change only after a bounded N4
failure and a later successful reprobe; initial capability setup is not
miscounted as a reconnect.

Except for the separately attributed fonts, these files are Copyright (c)
2026 Danila Sukharev and use `../LICENSE-BSD-2-Clause`.

The active console font is derived from Creep 0.31. Its exact BDF URL and
SHA-256 are pinned in `../tools/generate_creep_console_font.py`; the upstream
MIT terms and Romeo Van Snick attribution are in `LICENSE-CREEP`. Ordinary
letters and digits reserve their rightmost pixel as a separator. CP437 box
glyphs deliberately do the opposite: horizontal strokes occupy all five
pixels, and vertical strokes occupy the first and last scanlines, so repeated
cells form solid lines. The offline build needs no network or font package:

```sh
python3 tools/creep_console_oracle.py
python3 tools/locale_console_oracle.py
```

The oracle checks all 95 ASCII glyphs and the compact CP437 subset against the
readable reference, enforces text separation and connected pseudographics,
and independently renders all four video geometries.

The retained earlier font source is published as CC0 by domsson at
<https://opengameart.org/content/ascii-bitmap-font-oldschool>. Download
`charmap-oldschool_white.png` from that page and run:

```sh
python3 tools/generate_ram_console_font.py charmap-oldschool_white.png \
  --check platform/ram-console-font.asm
```

Regeneration is optional and requires Pillow; ordinary assembly consumes the
checked-in generated source and adds no image-library build dependency.

The Estonian bank is generated from the same pinned MIT Creep 0.31 BDF. The
Russian bank uses the public-domain Unicode 4x6 BDF distributed by u8g2 at
commit `ab9e48b2228351e9476682a70b7f3ee4909cd585`; its URL and SHA-256 are
pinned in `../tools/generate_locale_console_fonts.py`, and provenance is
retained in `LICENSE-U8G2-4X6`. Regenerate or verify both compact banks with:

```sh
python3 tools/generate_locale_console_fonts.py creep.bdf 4x6.bdf \
  --reference platform/locale-console-fonts-reference.txt \
  --assembly platform/locale-console-fonts.asm --check
```

Its older offline oracle verifies all 95 generated glyphs against the readable
source reference and can render a 400x192 PBM without executing the 8080
renderer:

```sh
python3 tools/ram_console_oracle.py \
  --render-text 'CP/M Plus 3.1 Juku | A> DIR' --pbm /tmp/juku-console.pbm
```

That sprite sheet has an unusual nine-pixel vertical pitch: seven glyph rows,
then two separator rows. The source reference and oracle deliberately keep
that extraction fact separate from the generated table so a bad generator
cannot validate itself.

Network-first ROM consumers call `JCGINIT` successfully before using another
gate entry. The gate selects memory mode 1 without clobbering the caller's
accumulator or flags; the first ABI keeps interrupts disabled while the ROM
owns the polled platform.

A transitional RAM framebuffer console that runs beside resident ROM defines
`RAMCONSOLE_MODE1`. Its bounded mode-3 pixel operations then restore mode 1 so
the next resident service remains callable. A fully RAM-owned BIOS omits it
and retains mode 3.

For an all-RAM consumer, S21 bits 2:1 select the display at console startup:

| bits 2:1 | text | cell | raster stride |
| --- | --- | --- | --- |
| `00` | 40x24 | 8x10 | 40 bytes |
| `01` | 53x24 | 6x10 | 40 bytes |
| `10` | 64x20 | 6x10 | 48 bytes |
| `11` | 80x24 | 5x8 | 50 bytes |

Every mode owns exactly 9,600 framebuffer bytes. The first three reproduce
the stock/EktaSoft timing writes; the fourth reproduces MODX. The current ABI
1 resident-ROM console intentionally remains the fixed 80x24 baseline, while
the all-RAM path proves the switchable policy before a future ABI extension.

The same cold-start sample selects the character bank with S21 bits 4:3:

| bits 4:3 | character bank |
| --- | --- |
| `00` | English ASCII plus CP437 UI glyphs |
| `01` | English plus ISO-8859-1 Estonian `ÄÕÖÜäõöü` |
| `10` | English plus Russian CP866; CP437 UI glyphs remain B0h..DFh |
| `11` | English/user-remap fallback |

Only the sparse extension tables change. Control handling, cell layout,
scrolling, cursor, and pixel painting remain one renderer.
