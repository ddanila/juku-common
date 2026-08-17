# Juku common

Small, proven building blocks shared by Juku software projects.

`diag/` contains diagnostics which can run in both bare-metal firmware and
CP/M programs. `music/` contains shared pitch/rhythm data for audible
diagnostic applications. `platform/` contains the Juku-owned RAM console,
polled keyboard, NetDisk-v3, remote-console, and optional CP/M Plus host-clock
transport used by more than one operating-system port. Clock GET commits its
five-byte SCB value only after a complete checksummed reply; SET is a
host-session offset and never changes the host OS clock. `transport/` contains
the common direct-fastboot
core and extension. Operating-system policy, memory maps, BIOS entry tables,
and build products remain in their consuming repositories.

Consumers should pin this repository as a Git submodule. The shared sources use
Intel 8080 mnemonics accepted by zmac in 8080 mode.

The original diagnostic and music modules are licensed under the MIT License.
The platform and transport modules are licensed under the BSD 2-Clause License
in `LICENSE-BSD-2-Clause`. The embedded ZX0 decoder retains its authorship and
license notice; see `transport/LICENSE.ZX0` and `transport/README.md`. The
active console font is derived from Romeo Van Snick's MIT-licensed Creep; see
`platform/LICENSE-CREEP` and `platform/README.md`.
The optional Cyrillic bank comes from a public-domain u8g2 BDF; see
`platform/LICENSE-U8G2-4X6` and `platform/README.md`.
