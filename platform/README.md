# Juku platform modules

These strict-8080 modules are shared by the CP/Mish Juku port and the separate
CP/M Plus Juku port:

- `ram-console.asm`: 40x24 framebuffer console;
- `ram-console-font.asm`: Daniel Hepper's public-domain `font8x8_basic`,
  bit-reversed for Juku scanout;
- `ram-keyboard.asm`: interrupt-independent matrix keyboard driver;
- `netdisk-v3.asm`: resilient three-record Janet read-ahead client;
- `netconsole.asm`: optional resilient remote console.

Consumers own their BIOS vectors, memory map, initialization policy, and disk
geometry. The assembly-time `CPM3ADAPTER` selection currently preserves the
two already-qualified workspace layouts while the CP/M Plus port replaces its
compatibility adapter with a native CP/M 3 hardware layer.

Except for the separately attributed public-domain font, these files are
Copyright (c) 2026 Danila Sukharev and use `../LICENSE-BSD-2-Clause`.
