# Juku direct-fastboot transport

`fastboot-core.asm` and `fastboot-extension.asm` implement the common strict
8080 direct-fastboot target used by the CP/Mish and CP/M Plus Juku ports. The
consumer selects its destination, entry point, system size, and protocol
features through assembly definitions; operating-system images and host policy
do not belong here.

The transport is Copyright (c) 2026 Danila Sukharev and uses
`../LICENSE-BSD-2-Clause`. Its embedded classic-format Intel 8080 ZX0 decoder
is by Ivan Gorodetsky, based on Einar Saukas's ZX0 decoder; their names remain
in the source and the upstream ZX0 license is preserved as `LICENSE.ZX0`.
