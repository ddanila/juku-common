# Juku network-first ROM ABI 1

The ABI exposes stable Juku hardware services from the 10 KiB ROM window
mapped at `D800h..FFFFh`. It is intentionally independent of CP/M 2.2 or 3;
an operating system owns only thin bindings and mutable low-RAM objects.

## Discovery and ownership

`FF00h` begins with `JUKUABI`, a zero byte, ABI major/minor, a 16-bit table
size, feature bits, a build-string pointer, required workspace bytes, and
copied-helper bytes. Fixed three-byte jump vectors begin at `FF20h`.

ABI 1 requires:

- the caller reserves `D600h..D7FFh`; the call gate starts at `D620h`, the
  mode-3 helper at `D700h`, and mutable ROM state at `D780h`;
- the stack and CP/M buffers do not overlap that range or `D800h` framebuffer;
- the PIC is masked and interrupt-driven RomBios services are detached;
- `JCGINIT` returns zero before any other gate entry is called;
- normal execution remains in memory mode 1. Only the copied framebuffer
  helper selects all-RAM mode 3, restores mode 1, and returns;
- every entry returns with interrupts disabled and memory mode 1 selected.

`JCGINIT` may be called from any memory mode. It checks all eight signature
bytes, requires the same major version and a ROM minor version no older than
the consumer, calls fixed-vector `JROMINIT`, records its result in low RAM, and
returns `A=00h` or `A=FFh`.
Consumers reject a mismatch cleanly; they never probe incidental ROM code.

Unless an entry says otherwise, AF, BC, DE, and HL may be destroyed, SP is
restored exactly, and no memory outside the fixed ROM workspace and explicit
caller buffers is modified. Bounded services report timeout rather than wait
forever.

## Vector contracts

| gate / ROM vector | contract |
| --- | --- |
| `JCGCONINIT` / `FF23h` | Initialize console timing, clear the screen, and reset position/cursor. ABI 1.0 uses fixed 80x24 MODX timing; ABI 1.1 uses reset-latched S21 bits 2:1 for 40x24, 53x24, 64x20, or 80x24. `A=0` success. |
| `JCGCONSTAT` / `FF26h` | `A=00h` no key, `A=FFh` key ready; advances the cursor blink. |
| `JCGCONIN` / `FF29h` | Bounded/local blocking input under the polled platform contract; returns character in A. |
| `JCGCONOUT` / `FF2Ch` | Input A is one character; supports CR/LF/backspace and `ESC L`; returns after local pixels are committed. |
| `JCGSERINIT` / `FF2Fh` | A=0 selects 19,200/8N1 bootstrap, A=1 selects 19,200/8O1 disk framing; returns A=0 or FFh. |
| `JCGSERRX` / `FF32h` | BC is a nonzero poll bound; CY clear and A=data, or CY set on timeout/error. |
| `JCGSERTX` / `FF35h` | A=data and BC is a nonzero poll bound; CY clear on accepted byte, set on timeout/error. |
| `JCGNETDISK` / `FF38h` | HL points to the versioned low-RAM request block; returns A=0 success or a nonzero status and invalidates partial cache state on error. |
| `JCGKEYINIT` / `FF3Bh` | Reset matrix/debounce state; A=0 success. |
| `JCGKEYSCAN` / `FF3Eh` | Nonblocking translated event scan used by console policy; returns and consumes one debounced key event, or A=0 when none. A physical key must be released before another event is accepted. |
| `JCGSOUND` / `FF41h` | A selects a built-in bounded cue; A=0 is silence, A=1 the diagnostic phrase. |
| `JCGDIAG` / `FF44h` | A selects a documented mechanism, HL points to its argument/result block; A is the structured result. Destructive tests are never implicit. |
| `JCGGETINFO` / `FF47h` | Returns HL=manifest address and DE=feature bits; no other state changes. |

ABI 1.1 appends two optional vectors when `JROMFLOCALE`/`JROMFKEYREMAP` are
advertised:

| gate / ROM vector | contract |
| --- | --- |
| `JCGCONFIG` / `FF4Ah` | Return the reset-latched raw S21 byte in A, decoded video mode in B, and locale in C. Locale is bits 4:3: English, Estonian, Russian CP866, or English/user fallback. |
| `JCGKEYREMAP` / `FF4Dh` | A is zero to disable remapping or 1..4, and HL points to that many input/output byte pairs. The bounded table is copied into resident state. Returns A=0. |

The ABI 1.0 vectors and behavior are unchanged. A 1.0 consumer accepts a 1.1
ROM and simply ignores the appended vectors; a 1.1 consumer rejects an older
ROM before calling them.

ABI 1.2 appends three optional, fixed vectors and advertises a feature bit for
each one. The ABI 1.0 and 1.1 addresses and contracts remain unchanged:

| gate / ROM vector | feature | contract |
| --- | --- | --- |
| `JCGCONBLOCK` / `FF53h` | `JROMFCONBLOCK` | HL points below `D800h`, BC is 1..256 bytes. Render the complete span with the ordinary console policy and one gate crossing. Return A=0/CY clear, or A=FFh/CY set for a zero, oversized, or overlay-crossing span. |
| `JCGNETMULTI` / `FF56h` | `JROMFNETMULTI` | HL points to a count byte (1..8) followed by that many ordinary ten-byte NetDisk-v1 request blocks. Execute in order and stop at the first nonzero status. Synchronous writes and every cache invalidation rule are identical to `JCGNETDISK`. |
| `JCGKEYRAW` / `FF59h` | `JROMFKEYRAW` | Instantaneous untranslated scan: CY clear returns A=column 0..14 and B=the complete row/modifier sample; CY set returns B=FFh when no key or modifier is active. S21 is excluded from contact detection. |

ABI 1.2's low-RAM gate remains 214 bytes. Its fixed vector slots use a single
register-preserving dispatcher, selected from the vector return address, so
the appended services do not collide with the helper at `D700h`. The resident
sound vector is also implemented and advertises `JROMFSOUND`: A=0 forces
silence and A=1 plays the bounded shared diagnostic phrase.

The ABI 1.1 console keeps the same resident text policy in every geometry.
Its copied mode-3 helper expands from 119 to the full 128-byte reserved helper
window so row stride, scroll extent, packed cell width, and cursor scanline
follow the latched mode without consuming operating-system RAM elsewhere.

`FF50h` is the ABI 1.1 ROM's internal reset-handoff vector. Boot-only code
jumps there after changing the memory overlay, avoiding non-relocatable branch
targets in the copied transition stub. It applies S21 bit 0: set proceeds to
the automatic network loader, while clear waits for a local `N` recovery key.
Operating systems do not call this vector.

NetDisk request version 1 is a 10-byte caller-owned block: version, operation,
drive, little-endian track, sector, little-endian 128-byte DMA pointer, and
little-endian three-slot cache pointer. Operation 0 reads one record through
the v3 read-ahead cache, operation 1 invalidates it, operation 2 selects the
mode in the drive byte (production uses 3), and operation 3 synchronously
writes one 128-byte DMA record. Write invalidates read-ahead before its first
attempt and never leaves cached data valid after an uncertain result. Reads and
writes return A=0 or A=1 after bounded three-attempt recovery; malformed
requests return FFh with carry set.

`FF20h` is `JROMINIT`, used by the boot path after installing the gate and
helper. It validates workspace/helper sizes, initializes fixed state, and
returns `A=0`; operating-system consumers normally inherit this initialized
state but may call it again during a controlled cold start.

The request block retains CP/M policy in the consumer while resident ROM owns
framing, retry, cache coherence, and the shared serial path. Feature bits
advertise only implemented services.

The ABI 1.1 C5 and ABI 1.2 implementations retain independent A:/B: validity and buffer
metadata when the caller supplies distinct cache pointers. A caller may still
reuse one pointer for both drives: an alias check invalidates the other drive
before the shared storage can be overwritten, so every ABI 1.0 consumer keeps
the original safe single-cache semantics.

## Compatibility rules

- Major changes may change calling conventions and are rejected by the gate.
- Minor changes may add feature bits, append manifest fields, or implement a
  previously unavailable fixed vector; existing behavior cannot be weakened.
- Build identity is diagnostic, never a compatibility key.
- Consumers test feature bits before optional calls.
- The ABI table and low-RAM layout are checked in simulation against exact
  addresses, stack sentinels, register preservation, interrupt state, memory
  mode, rejection of writes into the ROM overlay, successful mode-3 helper
  access, and concurrent serial traffic.
