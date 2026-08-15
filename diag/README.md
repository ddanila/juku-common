# Shared diagnostics

`memory.asm` provides a non-destructive byte-cell RAM check. It writes `00h`
and `FFh` to every byte in a half-open range, verifies both values, and restores
the original byte before advancing.

Interface for `diag_memory_test`:

- input: `HL` is the first address and `DE` is the exclusive end address;
- output: `A` is zero on success and nonzero if any tested bit disagreed;
- preserved: `DE` and every byte in the tested range;
- destroyed: `A`, `BC`, `HL`, and flags;
- precondition: the range does not wrap through `0000h` and must not contain
  live stack or code storage.

The routine is intentionally independent of CP/M and Jukuravi I/O, and uses no
stack space beyond its CALL return address. Those environments supply their own
entry point, safe range, reporting, and policy.

`cpu.asm` provides `diag_cpu_test`, an origin-independent and I/O-free 8080
CPU core. It checks arithmetic/logical results and flags, all four rotates,
INR/DCR carry preservation, DAA, BC/DE/HL increment paths, DAD, INX SP, and
PUSH/POP byte order. It specifically covers the high-bit INX failure observed
in CS00015's former D1. The routine returns a structured byte in A:

- `00h`: pass;
- `01h`: ALU, flag, rotate, or DAA failure;
- `02h`: register-pair, INX, or DAD failure;
- `04h`: SP or PUSH/POP path failure.

SP is restored exactly before return, including the SP-failure path. The
routine performs no static writes and is suitable for ROM or RAM callers, but
requires a writable stack with room for three extra words. BC, DE, HL, A, and
flags are destroyed.

## Future shared diagnostic suite

Keep `diag_memory_test` and the current no-argument CP/M `DIAG.COM` wrapper as
the small, non-destructive baseline. Future work should move the reusable test
cores proven by the Jukuravi diagnostic ROMs into this directory and expose
them through thin environment-specific front ends:

- ~~8080 instruction/flag and register-path tests;~~
- ROM integrity and RAM data/address/retention tests, including per-bit failure
  masks suitable for identifying D84..D91;
- PIC, PPI, PIT/D54-D55-D57, and local 8251 tests;
- framebuffer/video-path and clock/timing probes where they are safe under a
  running system.

The common routines should contain mechanisms and structured results, not ROM
beeps, serial framing, CP/M printing, or test policy. Jukuravi can continue to
provide the reset-safe ROM/host interface, while `DIAG.COM` can grow a readable
command-line selector and report results through CP/M. Every test must declare
which memory, interrupt, timer, console, and network state it modifies; unsafe
or destructive tests must be opt-in. Do not assume that a reset-time ROM test
can run unchanged under CP/M: preserve the operating system, stack, RomBios
interrupt dispatcher, raster/DRAM refresh, and Janet disk transport as needed.
