# Juku network-first ROM ABI 1.0

The ABI exposes stable Juku hardware services from the 10 KiB ROM window
mapped at `D800h..FFFFh`. It is intentionally independent of CP/M 2.2 or 3;
an operating system owns only thin bindings and mutable low-RAM objects.

## Discovery and ownership

`FF00h` begins with `JUKUABI`, a zero byte, ABI major/minor, a 16-bit table
size, feature bits, a build-string pointer, required workspace bytes, and
copied-helper bytes. Fixed three-byte jump vectors begin at `FF20h`.

ABI 1 requires:

- the caller reserves `D600h..D7FFh`; the call gate starts at `D640h`, the
  mode-3 helper at `D700h`, and mutable ROM state at `D780h`;
- the stack and CP/M buffers do not overlap that range or `D800h` framebuffer;
- the PIC is masked and interrupt-driven RomBios services are detached;
- `JCGINIT` returns zero before any other gate entry is called;
- normal execution remains in memory mode 1. Only the copied framebuffer
  helper selects all-RAM mode 3, restores mode 1, and returns;
- every entry returns with interrupts disabled and memory mode 1 selected.

`JCGINIT` may be called from any memory mode. It checks all eight signature
bytes, requires the same major version and a ROM minor version no older than
the consumer, records its result in low RAM, and returns `A=00h` or `A=FFh`.
Consumers reject a mismatch cleanly; they never probe incidental ROM code.

Unless an entry says otherwise, AF, BC, DE, and HL may be destroyed, SP is
restored exactly, and no memory outside the fixed ROM workspace and explicit
caller buffers is modified. Bounded services report timeout rather than wait
forever.

## Vector contracts

| gate / ROM vector | contract |
| --- | --- |
| `JCGCONINIT` / `FF23h` | Initialize MODX timing, clear the screen, reset position/cursor. `A=0` success. |
| `JCGCONSTAT` / `FF26h` | `A=00h` no key, `A=FFh` key ready; advances the cursor blink. |
| `JCGCONIN` / `FF29h` | Bounded/local blocking input under the polled platform contract; returns character in A. |
| `JCGCONOUT` / `FF2Ch` | Input A is one character; supports CR/LF/backspace and `ESC L`; returns after local pixels are committed. |
| `JCGSERINIT` / `FF2Fh` | A=0 selects 19,200/8N1 bootstrap, A=1 selects 19,200/8O1 disk framing; returns A=0 or FFh. |
| `JCGSERRX` / `FF32h` | BC is a nonzero poll bound; CY clear and A=data, or CY set on timeout/error. |
| `JCGSERTX` / `FF35h` | A=data and BC is a nonzero poll bound; CY clear on accepted byte, set on timeout/error. |
| `JCGNETDISK` / `FF38h` | HL points to the versioned low-RAM request block; returns A=0 success or a nonzero status and invalidates partial cache state on error. |
| `JCGKEYINIT` / `FF3Bh` | Reset matrix/debounce state; A=0 success. |
| `JCGKEYSCAN` / `FF3Eh` | Nonblocking raw/translated scan used by console policy; A=0 means none. |
| `JCGSOUND` / `FF41h` | A selects a built-in bounded cue; A=0 is silence, A=1 the diagnostic phrase. |
| `JCGDIAG` / `FF44h` | A selects a documented mechanism, HL points to its argument/result block; A is the structured result. Destructive tests are never implicit. |
| `JCGGETINFO` / `FF47h` | Returns HL=manifest address and DE=feature bits; no other state changes. |

`FF20h` is `JROMINIT`, used by the boot path after installing the gate and
helper. It validates workspace/helper sizes, initializes fixed state, and
returns `A=0`; operating-system consumers normally inherit this initialized
state but may call it again during a controlled cold start.

The initial NetDisk request block is deliberately defined with policy in the
consumer adapter until the shared serial extraction is complete. ABI 1.0 may
implement `JROMNETDISK` as unavailable (`A=FFh`) during the skeleton phase, but
the fixed address and eventual timeout/state rules may not change. Feature bits
advertise only implemented services.

## Compatibility rules

- Major changes may change calling conventions and are rejected by the gate.
- Minor changes may add feature bits, append manifest fields, or implement a
  previously unavailable fixed vector; existing behavior cannot be weakened.
- Build identity is diagnostic, never a compatibility key.
- Consumers test feature bits before optional calls.
- The ABI table and low-RAM layout are checked in simulation against exact
  addresses, stack sentinels, register preservation, interrupt state, memory
  mode, framebuffer write-through, mode-3 helper return, and serial traffic.
