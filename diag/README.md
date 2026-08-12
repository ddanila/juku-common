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
