# Juku direct-fastboot transport

`fastboot-core.asm` and `fastboot-extension.asm` implement the common strict
8080 direct-fastboot target used by the CP/Mish and CP/M Plus Juku ports. The
consumer selects its destination, entry point, system size, and protocol
features through assembly definitions; operating-system images and host policy
do not belong here.

Defining `FASTBOOT_BOOT_RECORD` makes the V15 extension retain its current
system-stream stage and saturating CRC retry count at `D611h..D612h`. It is
optional so frozen consumers remain byte-exact; the network-first ABI 1.1
consumer supplies the surrounding POST/core/protocol fields.

`FASTBOOT_V17` with `FASTBOOT_9600` is the stock-ROM recovery transport. Its
one Janet-loaded record explicitly restores the factory D57 channel-0 mode-3
count-8 clock and keeps D11 at 9600/8O1 for the extension and compressed
system. The checked `JR 17 00` marker distinguishes it from the historical
JF15 19200/8N1 handoff, so a host cannot silently pair the wrong baud policy
with an otherwise valid artifact.

The transport is Copyright (c) 2026 Danila Sukharev and uses
`../LICENSE-BSD-2-Clause`. Its embedded classic-format Intel 8080 ZX0 decoder
is by Ivan Gorodetsky, based on Einar Saukas's ZX0 decoder; their names remain
in the source and the upstream ZX0 license is preserved as `LICENSE.ZX0`.
