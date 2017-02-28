# Targets

Nerves provides support for a set of common Targets.
Each Target is referenced with a unique tag name.
These tags are used when choosing which System and Toolchain to compile with.
It is important to note that a single tag may offer support for more than one board.

## Supported Targets and Systems

Target | System | Tag
--- | --- | ---
Raspberry Pi A+, B, B+ and Zero | [nerves_system_rpi](https://github.com/nerves-project/nerves_system_rpi) | `rpi`
Raspberry Pi 2 | [nerves_system_rpi2](https://github.com/nerves-project/nerves_system_rpi2) | `rpi2`
Raspberry Pi 3 | [nerves_system_rpi3](https://github.com/nerves-project/nerves_system_rpi3) | `rpi3`
BeagleBone Black | [nerves_system_bbb](https://github.com/nerves-project/nerves_system_bbb) | `bbb`
Alix | [nerves_system_alix](https://github.com/nerves-project/nerves_system_alix) | `alix`
AG150 | [nerves_system_ag150](https://github.com/nerves-project/nerves_system_ag150) | `ag150`
Intel Galileo 2 | [nerves_system_galileo](https://github.com/nerves-project/nerves_system_galileo) | `galileo`
Lego EV3 | [nerves_system_ev3](https://github.com/nerves-project/nerves_system_ev3) | `ev3`
QEmu Arm | [nerves_system_qemu_arm](https://github.com/nerves-project/nerves_system_qemu_arm) | `qemu_arm`

