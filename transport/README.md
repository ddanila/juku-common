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

The transport is Copyright (c) 2026 Danila Sukharev and uses
`../LICENSE-BSD-2-Clause`. Its embedded classic-format Intel 8080 ZX0 decoder
is by Ivan Gorodetsky, based on Einar Saukas's ZX0 decoder; their names remain
in the source and the upstream ZX0 license is preserved as `LICENSE.ZX0`.
