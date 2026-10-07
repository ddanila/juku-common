# Shared diagnostics

`memory.asm` provides a non-destructive byte-cell RAM check. It writes `00h`
and `FFh` to every byte in a half-open range, verifies both values, and restores
the original byte before advancing.

Interface for `diag_memory_test`:

- input: `HL` is the first address and `DE` is the exclusive end address;
- output: `A` is zero on success and nonzero if any tested bit disagreed;
- preserved: `DE` and every byte in the tested range;
- destroyed: `A`, `BC`, `HL`, and flags;
- precondition: `HL < DE` at entry; the range must be nonempty, must not wrap
  through `0000h`, and must not contain live stack or code storage.

The routine is intentionally independent of CP/M and Jukuravi I/O, and uses no
stack space beyond its CALL return address. Those environments supply their own
entry point, safe range, reporting, and policy.

`cpu.asm` provides `diag_cpu_test`, an origin-independent and I/O-free 8080
CPU core. It checks arithmetic/logical results and flags, all four rotates,
INR/DCR carry preservation, DAA, BC/DE/HL increment paths, DAD, INX SP, and
PUSH/POP byte order. The routine returns a structured byte in A:

- `00h`: pass;
- `01h`: ALU, flag, rotate, or DAA failure;
- `02h`: register-pair, INX, or DAD failure;
- `04h`: SP or PUSH/POP path failure.

SP is restored exactly before return, including the SP-failure path. The
routine performs no static writes and is suitable for ROM or RAM callers, but
requires a writable stack with room for three extra words. BC, DE, HL, A, and
flags are destroyed.

`memory-address.asm` provides a complementary non-destructive address-alias
test. `HL` is an aligned base byte and `A` is the number of address bits
(1..15); the routine compares the base with every `base+(1<<n)` location,
restores every byte, and returns zero or one in `A`. The complete tested span
must be writable and must not contain live code or stack. It destroys BC, DE,
HL, A and flags and needs five extra stack words.

`memory-retention.asm` provides a non-destructive single-cell hold test. `HL`
selects the writable byte and nonzero `BC` selects the delay-loop count. It
holds `00h` and `FFh`, returns the accumulated data-bit mismatch mask in `A`,
and restores the byte, HL and BC. It destroys DE, A and flags and needs two
extra stack words beyond the CALL return address. The caller owns the clock/refresh policy and
must ensure that its code and stack survive the hold; the common routine does
not disable refresh.

`checksum.asm` provides `diag_checksum8`. `HL` and `DE` delimit a half-open
range and `A` receives its eight-bit additive checksum. DE and the checked
bytes are preserved; A, C, HL and flags are destroyed. The range must be
nonempty with `HL < DE` at entry; the loop does not accept an empty range.
A ROM front end can
compare this result with a stored checksum, while a RAM program can use the
same primitive without embedding ROM layout policy in the common source.

`pit-d57.asm` safely latches the already-running D57 channel-0 count and
accepts the production mode-2/count-4 range 1..4 without reprogramming the
USART clock. `usart-status.asm` reads, but does not clear, the 8251 PE/OE/FE
bits; readiness is intentionally not judged outside a defined half-duplex
turn. Consumers provide the two port constants.

`s21-config.asm` performs a bounded direct scan of keyboard columns 8..15 and
returns the raw eight-position S21 configuration byte. It restores the
previously selected keyboard column and does not call RomBios or a JukuNet ROM
service, so a live CP/M front end can use the same mechanism with either ROM
family. Consumers provide the D26 column and row port constants.

`signature.asm` provides `diag_signature_test`: HL points to observed bytes,
DE to expected bytes, and B is a nonzero byte count. It returns A=0 for an
exact match or A=1 for a mismatch, preserves memory and C, and destroys A, B,
DE, HL and flags. It is used by the CP/M front end for the fixed ROM ABI
manifest and remains independent of memory-map policy.

## Consumer policy

Common routines provide mechanisms and structured results. Consumers own ROM
beeps, serial framing, CP/M printing, test selection and reporting. Each front
end must declare which memory, interrupt, timer, console and network state it
modifies; intrusive tests require explicit selection.

Reset-time ROM tests cannot be assumed safe under CP/M. Preserve the operating
system, stack, RomBios interrupt dispatcher, raster/DRAM refresh and Janet disk
transport. PIC, PPI, intrusive raster and framebuffer probes need a separate
safety contract before being added to a running-system suite.
