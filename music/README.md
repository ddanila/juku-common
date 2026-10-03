# Shared music data

`smoke-player.asm` is a readable, origin-independent Intel 8080 routine which
programs D57 channel 1, traverses the phrase, provides register-only note/rest
timing, silences the speaker, and returns. Assemble it with zmac in Intel 8080
mode and include `smoke-table.asm` after it.

`smoke-table.asm` is the twelve-note, four-bar, 112 BPM diagnostic phrase
first proven on physical Juku CS00015 through Jukuravi. It contains only the
D57 channel-1 divisors and the sounding/silent eighth-note counts, so a
bare-metal monitor payload and a CP/M transient can share the exact phrase
while retaining their own entry, completion, and timing contracts.

The table label is `note_table`. Each of its twelve entries is a little-endian
16-bit divisor followed by one-byte sounding and silent durations. D57 channel
1 uses its nominal 2 MHz source clock for pitch. The table's intended eighth
note is `60 / 112 / 2` seconds. The supplied `smoke_play` implementation uses
a fixed 22,321-iteration delay calibrated for a nominal 2 MHz CPU; it does not
measure elapsed time or compensate for READY waits. Actual tempo follows the
effective CPU execution rate, independently of the PIT's pitch clock.

`smoke_play` takes no arguments, preserves memory and SP, destroys A/BC/DE/HL
and flags, and leaves interrupts disabled. It touches only D57 channel 1;
environment-specific wrappers remain responsible for completion reporting,
restoring interrupt policy, or returning to a monitor/operating system.
