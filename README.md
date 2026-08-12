# Juku common

Small, proven building blocks shared by Juku software projects.

The repository deliberately starts narrow. `diag/` contains diagnostics which
can run in both bare-metal firmware and CP/M programs. `music/` contains shared
pitch/rhythm data for audible diagnostic applications. Hardware-specific user
interfaces, drivers, and policy remain in their consuming repositories.

Consumers should pin this repository as a Git submodule. The shared sources use
Intel 8080 mnemonics accepted by zmac in 8080 mode.

Licensed under the MIT License.
