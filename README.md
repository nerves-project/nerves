# Nerves

[![Backers on Open Collective](https://opencollective.com/nerves-project/backers/badge.svg)](#backers)
[![Sponsors on Open Collective](https://opencollective.com/nerves-project/sponsors/badge.svg)](#sponsors)
[![CircleCI](https://circleci.com/gh/nerves-project/nerves/tree/main.svg?style=svg)](https://circleci.com/gh/nerves-project/nerves/tree/main)
[![Hex version](https://img.shields.io/hexpm/v/nerves.svg "Hex version")](https://hex.pm/packages/nerves)

## Craft and deploy bulletproof embedded software in Elixir

Nerves provides tooling and libraries for building small, self-contained
software images using the rock-solid [Erlang virtual
machine](https://www.erlang.org/) hardware support of Linux, and happy
development experience of Elixir for microprocessor-based embedded systems.

While the Nerves project provides base runtime libraries for hardware access and
network configuration, nearly all of the Elixir ecosystem is available,
including:

* [Phoenix](https://www.phoenixframework.org/) and LiveView for interactive
  local web user interfaces
* [Elixir Nx](https://github.com/elixir-nx/nx) for numerical computing and
  machine learning
* [Livebook](https://livebook.dev/) for interactive code notebooks on your device
* [Scenic](https://github.com/boydm/scenic) for local on-screen user interfaces

Or just keep it simple and use whatever libraries you need from the
[Hex package manager](https://hex.pm/). Nerves only includes what you use so
your embedded software can remain small.

Nerves uses the Linux kernel to support a large variety of hardware. It is not a
Linux distribution, though, and contains little of what you would find on a
typical embedded Linux system. Instead, it starts the Erlang runtime as one of
the first OS processes and lets Erlang and Elixir take over from there. Not to
fear, if you need something from Linux, Nerves provides a way to use most of the
packages available through [Buildroot](https://buildroot.org).

## Nerves Projects

Our project is spread over many repositories in order to focus on a limited
scope per repository.

This repository
(**[nerves-project/nerves](https://github.com/nerves-project/nerves)**) is an
entrance to Nerves and provides the core tooling and documentation.

The Nerves core team maintains the projects in the `nerves-project` organization
with the help of many in the Elixir community. Projects under other GitHub
organizations are maintained by their respective organization, but listed here
since they're so commonly used in conjunction with the core libraries and tools.

### Framework / Core

| Name | Description | Release |
| -------------------------: | :------------------------------------------------------------------------------------------ | :-------------------------------------------------------- |
| **[Erlinit](https://github.com/nerves-project/erlinit)** | Replacement for /sbin/init that launches an Erlang/OTP Release | ![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/nerves-project/erlinit?sort=semver) |
| **[Nerves.Bootstrap](https://github.com/nerves-project/nerves_bootstrap)** | The Nerves new project generator and low level hooks into Mix | [![Hex.pm](https://img.shields.io/hexpm/v/nerves_bootstrap.svg)](https://hex.pm/packages/nerves_bootstrap) |
| **[Nerves.Runtime](https://github.com/nerves-project/nerves_runtime)** | Small, general runtime utilities for Nerves devices | [![Hex.pm](https://img.shields.io/hexpm/v/nerves_runtime.svg)](https://hex.pm/packages/nerves_runtime) |
| **[NervesPack](https://github.com/nerves-project/nerves_pack)** | Initialization setup for Nerves devices | [![Hex.pm](https://img.shields.io/hexpm/v/nerves_pack.svg)](https://hex.pm/packages/nerves_pack) |
| **[NervesSystemBR](https://github.com/nerves-project/nerves_system_br)** | Buildroot based build platform for Nerves Systems | [![Hex.pm](https://img.shields.io/hexpm/v/nerves_system_br.svg)](https://hex.pm/packages/nerves_system_br) |
| **[RingLogger](https://github.com/nerves-project/ring_logger)** | A ring buffer backend for Elixir Logger with IO streaming | [![Hex.pm](https://img.shields.io/hexpm/v/ring_logger.svg)](https://hex.pm/packages/ring_logger) |

### Example projects

| Name | Description | Release |
| -------------------------: | :------------------------------------------------------------------------------------------ | :-------------------------------------------------------- |
| **[Circuits Quickstart](https://github.com/elixir-circuits/circuits_quickstart)** | Try out Elixir Circuits with prebuilt Nerves firmware | ![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/elixir-circuits/circuits_quickstart?sort=semver) |
| **[NervesExamples](https://github.com/nerves-project/nerves_examples)** | Small example programs using Nerves | |
| **[Nerves Livebook](https://github.com/nerves-livebook/nerves_livebook)** | Develop on embedded devices with Livebook and Nerves | ![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/nerves-livebook/nerves_livebook?sort=semver) |

### Hardware

These are the officially supported hardware ports. Many others exist in the
community.

| Name | Description | Release |
| -------------------------: | :------------------------------------------------------------------------------------------ | :-------------------------------------------------------- |
| **[NervesSystemBBB](https://github.com/nerves-project/nerves_system_bbb)** | Base Nerves system configuration for the BeagleBone-based boards | [![Hex.pm](https://img.shields.io/hexpm/v/nerves_system_bbb.svg)](https://hex.pm/packages/nerves_system_bbb) |
| **[NervesSystemOSD32MP1](https://github.com/nerves-project/nerves_system_osd32mp1)** | Base system for Octavo OSD32MP1 | [![Hex.pm](https://img.shields.io/hexpm/v/nerves_system_osd32mp1.svg)](https://hex.pm/packages/nerves_system_osd32mp1) |
| **[NervesSystemRPi](https://github.com/nerves-project/nerves_system_rpi)** | Base Nerves system configuration for the Raspberry Pi A+ and B+ | [![Hex.pm](https://img.shields.io/hexpm/v/nerves_system_rpi.svg)](https://hex.pm/packages/nerves_system_rpi) |
| **[NervesSystemRPi0](https://github.com/nerves-project/nerves_system_rpi0)** | Base Nerves system configuration for the Raspberry Pi Zero and Zero W | [![Hex.pm](https://img.shields.io/hexpm/v/nerves_system_rpi0.svg)](https://hex.pm/packages/nerves_system_rpi0) |
| **[NervesSystemRPi2](https://github.com/nerves-project/nerves_system_rpi2)** | Base Nerves system configuration for the Raspberry Pi 2 | [![Hex.pm](https://img.shields.io/hexpm/v/nerves_system_rpi2.svg)](https://hex.pm/packages/nerves_system_rpi2) |
| **[NervesSystemRPi3](https://github.com/nerves-project/nerves_system_rpi3)** | Base Nerves system configuration for the Raspberry Pi 3 | [![Hex.pm](https://img.shields.io/hexpm/v/nerves_system_rpi3.svg)](https://hex.pm/packages/nerves_system_rpi3) |
| **[NervesSystemRPi3A](https://github.com/nerves-project/nerves_system_rpi3a)** | Nerves system for the Raspberry Pi 3 Model A+ w/ gadget mode and Raspberry Pi Zero 2 W | [![Hex.pm](https://img.shields.io/hexpm/v/nerves_system_rpi3a.svg)](https://hex.pm/packages/nerves_system_rpi3a) |
| **[NervesSystemRPi4](https://github.com/nerves-project/nerves_system_rpi4)** | Base Nerves system configuration for the Raspberry Pi 4 | [![Hex.pm](https://img.shields.io/hexpm/v/nerves_system_rpi4.svg)](https://hex.pm/packages/nerves_system_rpi4) |
| NervesSystemRPi5 | Not available yet. See the [discussion on ElixirForum](https://elixirforum.com/t/support-for-rpi-5/59915/3) for more info. | |
| **[NervesSystemVultr](https://github.com/nerves-project/nerves_system_vultr)** | Experimental configuration for a Vultr cloud server | [![Hex.pm](https://img.shields.io/hexpm/v/nerves_system_vultr.svg)](https://hex.pm/packages/nerves_system_vultr) |
| **[NervesSystemX86_64](https://github.com/nerves-project/nerves_system_x86_64)** | Generic Nerves system configuration x86_64 based hardware | [![Hex.pm](https://img.shields.io/hexpm/v/nerves_system_x86_64.svg)](https://hex.pm/packages/nerves_system_x86_64) |
| **[NervesSystemGrisp2](https://github.com/nerves-project/nerves_system_grisp2)** |Base Nerves system configuration for the GRiSP 2 | [![Hex.pm](https://img.shields.io/hexpm/v/nerves_system_grisp2.svg)](https://hex.pm/packages/nerves_system_grisp2) |
| **[NervesSystemMangoPiMQPro](https://github.com/nerves-project/nerves_system_mangopi_mq_pro)** |Base Nerves system configuration for the MangoPi MQ-Pro | [![Hex.pm](https://img.shields.io/hexpm/v/nerves_system_mangopi_mq_pro.svg)](https://hex.pm/packages/nerves_system_mangopi_mq_pro) |

### Networking

| Name | Description | Release |
| -------------------------: | :------------------------------------------------------------------------------------------ | :-------------------------------------------------------- |
| **[VintageNet](https://github.com/nerves-networking/vintage_net)** | Network configuration and management for Nerves | [![Hex.pm](https://img.shields.io/hexpm/v/vintage_net.svg)](https://hex.pm/packages/vintage_net) |
| **[VintageNetWiFi](https://github.com/nerves-networking/vintage_net_wifi)** | WiFi networking for VintageNet | [![Hex.pm](https://img.shields.io/hexpm/v/vintage_net_wifi.svg)](https://hex.pm/packages/vintage_net_wifi) |
| **[VintageNetDirect](https://github.com/nerves-networking/vintage_net_direct)** | Direct network connection support for VintageNet | [![Hex.pm](https://img.shields.io/hexpm/v/vintage_net_direct.svg)](https://hex.pm/packages/vintage_net_direct) |
| **[VintageNetEthernet](https://github.com/nerves-networking/vintage_net_ethernet)** | Ethernet support for VintageNet | [![Hex.pm](https://img.shields.io/hexpm/v/vintage_net_ethernet.svg)](https://hex.pm/packages/vintage_net_ethernet) |
| **[VintageNetMobile](https://github.com/nerves-networking/vintage_net_mobile)** | Mobile connection support for VintageNet | [![Hex.pm](https://img.shields.io/hexpm/v/vintage_net_mobile.svg)](https://hex.pm/packages/vintage_net_mobile) |
| **[VintageNetQMI](https://github.com/nerves-networking/vintage_net_qmi)** | VintageNet technology support for QMI mobile connections | [![Hex.pm](https://img.shields.io/hexpm/v/vintage_net_qmi.svg)](https://hex.pm/packages/vintage_net_qmi) |
| **[VintageNetWireGuard](https://github.com/nerves-networking/vintage_net_wireguard)** | Wireguard VPN support | [![Hex.pm](https://img.shields.io/hexpm/v/vintage_net_wireguard.svg)](https://hex.pm/packages/vintage_net_wireguard) |

### Hardware access

| Name | Description | Release |
| -------------------------: | :------------------------------------------------------------------------------------------ | :-------------------------------------------------------- |
| **[Circuits.GPIO](https://github.com/elixir-circuits/circuits_gpio)** | Use GPIOs in Elixir | [![Hex.pm](https://img.shields.io/hexpm/v/circuits_gpio.svg)](https://hex.pm/packages/circuits_gpio) |
| **[Circuits.I2C](https://github.com/elixir-circuits/circuits_i2c)** | Use I2C in Elixir | [![Hex.pm](https://img.shields.io/hexpm/v/circuits_i2c.svg)](https://hex.pm/packages/circuits_i2c) |
| **[Circuits.SPI](https://github.com/elixir-circuits/circuits_spi)** | Communicate over SPI from Elixir | [![Hex.pm](https://img.shields.io/hexpm/v/circuits_spi.svg)](https://hex.pm/packages/circuits_spi) |
| **[Circuits.UART](https://github.com/elixir-circuits/circuits_uart)** | Discover and use UARTs and serial ports in Elixir | [![Hex.pm](https://img.shields.io/hexpm/v/circuits_uart.svg)](https://hex.pm/packages/circuits_uart) |

### SSH and Shell

| Name | Description | Release |
| -------------------------: | :------------------------------------------------------------------------------------------ | :-------------------------------------------------------- |
| **[NervesMOTD](https://github.com/nerves-project/nerves_motd)** | Message of the day for Nerves devices | [![Hex.pm](https://img.shields.io/hexpm/v/nerves_motd.svg)](https://hex.pm/packages/nerves_motd) |
| **[NervesSSH](https://github.com/nerves-project/nerves_ssh)** | Manage an SSH daemon and subsystems on Nerves devices | [![Hex.pm](https://img.shields.io/hexpm/v/nerves_ssh.svg)](https://hex.pm/packages/nerves_ssh) |
| **[SSHSubsystemFwup](https://github.com/nerves-project/ssh_subsystem_fwup)** | Erlang SSH Subsystem for Nerves firmware updates | [![Hex.pm](https://img.shields.io/hexpm/v/ssh_subsystem_fwup.svg)](https://hex.pm/packages/ssh_subsystem_fwup) |
| **[Toolshed](https://github.com/elixir-toolshed/toolshed)** | A toolshed of shell-like IEx helpers | [![Hex.pm](https://img.shields.io/hexpm/v/toolshed.svg)](https://hex.pm/packages/toolshed) |

### Toolchain

Nerves provides a C/C++ cross-toolchain to ensure consistency builds on all
supported host platforms. These are built using
[crosstool-ng](https://github.com/crosstool-ng/crosstool-ng) and are similar to
other GCC toolchains.

| Name | Description | Release |
| -------------------------: | :------------------------------------------------------------------------------------------ | :-------------------------------------------------------- |
|  **[nerves_toolchain_ctng](https://github.com/nerves-project/toolchains/tree/main/nerves_toolchain_ctng)** | Crosstool-NG integration for building Nerves toolchains | [![Hex.pm](https://img.shields.io/hexpm/v/nerves_toolchain_ctng.svg)](https://hex.pm/packages/nerves_toolchain_ctng) |
|  **[nerves_toolchain_aarch64_nerves_linux_gnu](https://github.com/nerves-project/toolchains/tree/main/nerves_toolchain_aarch64_nerves_linux_gnu)** | 64-bit ARM toolchain | [![Hex.pm](https://img.shields.io/hexpm/v/nerves_toolchain_aarch64_nerves_linux_gnu.svg)](https://hex.pm/packages/nerves_toolchain_aarch64_nerves_linux_gnu) |
|  **[nerves_toolchain_armv5_nerves_linux_musleabi](https://github.com/nerves-project/toolchains/tree/main/nerves_toolchain_armv5_nerves_linux_musleabi)** | 32-bit ARM toolchain for older ARM processors | [![Hex.pm](https://img.shields.io/hexpm/v/nerves_toolchain_armv5_nerves_linux_musleabi.svg)](https://hex.pm/packages/nerves_toolchain_armv5_nerves_linux_musleabi) |
|  **[nerves_toolchain_armv6_nerves_linux_gnueabihf](https://github.com/nerves-project/toolchains/tree/main/nerves_toolchain_armv6_nerves_linux_gnueabihf)** | 32-bit ARM toolchain for Raspberry Pi A, B, and Zero | [![Hex.pm](https://img.shields.io/hexpm/v/nerves_toolchain_armv6_nerves_linux_gnueabihf.svg)](https://hex.pm/packages/nerves_toolchain_armv6_nerves_linux_gnueabihf) |
|  **[nerves_toolchain_armv7_nerves_linux_gnueabihf](https://github.com/nerves-project/toolchains/tree/main/nerves_toolchain_armv7_nerves_linux_gnueabihf)** | 32-bit ARM toolchain for most 32-bit ARMs | [![Hex.pm](https://img.shields.io/hexpm/v/nerves_toolchain_armv7_nerves_linux_gnueabihf.svg)](https://hex.pm/packages/nerves_toolchain_armv7_nerves_linux_gnueabihf) |
|  **[nerves_toolchain_i586_nerves_linux_gnu](https://github.com/nerves-project/toolchains/tree/main/nerves_toolchain_i586_nerves_linux_gnu)** | 32-bit Intel x86 toolchain | [![Hex.pm](https://img.shields.io/hexpm/v/nerves_toolchain_i586_nerves_linux_gnu.svg)](https://hex.pm/packages/nerves_toolchain_i586_nerves_linux_gnu) |
|  **[nerves_toolchain_mipsel_nerves_linux_musl](https://github.com/nerves-project/toolchains/tree/main/nerves_toolchain_mipsel_nerves_linux_musl)** | 32-bit MIPS toolchain | [![Hex.pm](https://img.shields.io/hexpm/v/nerves_toolchain_mipsel_nerves_linux_musl.svg)](https://hex.pm/packages/nerves_toolchain_mipsel_nerves_linux_musl) |
|  **[nerves_toolchain_riscv64_nerves_linux_gnu](https://github.com/nerves-project/toolchains/tree/main/nerves_toolchain_riscv64_nerves_linux_gnu)** | 64-bit RISC-V toolchain | [![Hex.pm](https://img.shields.io/hexpm/v/nerves_toolchain_riscv64_nerves_linux_gnu.svg)](https://hex.pm/packages/nerves_toolchain_riscv64_nerves_linux_gnu) |
|  **[nerves_toolchain_x86_64_nerves_linux_musl](https://github.com/nerves-project/toolchains/tree/main/nerves_toolchain_x86_64_nerves_linux_musl)** | 64-bit x86 toolchain using the musl libc | [![Hex.pm](https://img.shields.io/hexpm/v/nerves_toolchain_x86_64_nerves_linux_musl.svg)](https://hex.pm/packages/nerves_toolchain_x86_64_nerves_linux_musl) |
|  **[nerves_toolchain_x86_64_nerves_linux_gnu](https://github.com/nerves-project/toolchains/tree/main/nerves_toolchain_x86_64_nerves_linux_gnu)** | 64-bit x86 toolchain using GNU libc | [![Hex.pm](https://img.shields.io/hexpm/v/nerves_toolchain_x86_64_nerves_linux_gnu.svg)](https://hex.pm/packages/nerves_toolchain_x86_64_nerves_linux_gnu) |

### Miscellaneous

| Name | Description | Release |
| -------------------------: | :------------------------------------------------------------------------------------------ | :-------------------------------------------------------- |
| **[boardid](https://github.com/nerves-project/boardid)** | Print out a platform-specific board serial number | ![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/nerves-project/boardid?sort=semver) |
| **[NervesFWLoaders](https://github.com/nerves-project/nerves_fw_loaders)** | A collection of firmware loaders for boards with internal storage | ![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/nerves-project/nerves_fw_loaders?sort=semver) |
| **[NervesHeart](https://github.com/nerves-project/nerves_heart)** | Erlang heartbeat support for Nerves | ![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/nerves-project/nerves_heart?sort=semver) |
| **[Shoehorn](https://github.com/nerves-project/shoehorn)** | Help handle OTP application failures and start order | [![Hex.pm](https://img.shields.io/hexpm/v/shoehorn.svg)](https://hex.pm/packages/shoehorn) |
| **[UBootEnv](https://github.com/nerves-project/uboot_env)** | Read and write to U-Boot environment blocks | [![Hex.pm](https://img.shields.io/hexpm/v/uboot_env.svg)](https://hex.pm/packages/uboot_env) |

### Upcoming

These projects are new or experimental and are in various stages of being ready
to promote to the above categories.

| Name | Description | Release |
| -------------------------: | :------------------------------------------------------------------------------------------ | :-------------------------------------------------------- |
| **[NervesLogging](https://github.com/nerves-project/nerves_logging)** | Route system log messages through the Elixir logger | [![Hex.pm](https://img.shields.io/hexpm/v/nerves_logging.svg)](https://hex.pm/packages/nerves_logging) |
| **[NervesUEvent](https://github.com/nerves-project/nerves_uevent)** | Simple UEvent monitor for detecting hardware and automatically loading drivers | [![Hex.pm](https://img.shields.io/hexpm/v/nerves_uevent.svg)](https://hex.pm/packages/nerves_uevent) |
| **[PropertyTable](https://github.com/jjcarstens/property_table)** | In-memory key-value store with subscriptions | [![Hex.pm](https://img.shields.io/hexpm/v/property_table.svg)](https://hex.pm/packages/property_table) |
| **[nerves_initramfs](https://github.com/nerves-project/nerves_initramfs)** | An initramfs for early boot handling of Nerves devices | ![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/nerves-project/nerves_initramfs?sort=semver) |
| **[nerves_system_linter](https://github.com/nerves-project/nerves_system_linter)** | Mix task to check Nerves system configuration files | [![Hex.pm](https://img.shields.io/hexpm/v/nerves_system_linter.svg)](https://hex.pm/packages/nerves_system_linter) |
| **[nerves_systems](https://github.com/nerves-project/nerves_systems)** | Build scripts for maintaining multiple repositories | _unreleased_ |

<details>
<summary><b>See outdated/inactive projects...</b></summary><br />

| Name | Description | Release |
| -------------------------: | :------------------------------------------------------------------------------------------ | :-------------------------------------------------------- |
| **[nerves_leds](https://github.com/nerves-project/nerves_leds)** | Functions to drive LEDs on embedded systems | [![Hex.pm](https://img.shields.io/hexpm/v/nerves_leds.svg)](https://hex.pm/packages/nerves_leds) |
| **[system_registry](https://github.com/nerves-project/system_registry)** | Serial nested term storage and dispatch registry | [![Hex.pm](https://img.shields.io/hexpm/v/system_registry.svg)](https://hex.pm/packages/system_registry) |
| **[system_registry_term_storage](https://github.com/nerves-attic/system_registry_term_storage)** | Simple term storage for SystemRegistry | [![Hex.pm](https://img.shields.io/hexpm/v/system_registry_term_storage.svg)](https://hex.pm/packages/system_registry_term_storage) |
| **[nerves_system_test](https://github.com/nerves-project/nerves_system_test)** | | |
| **[nerves_test_server](https://github.com/nerves-project/nerves_test_server)** | | |

There is also a gravesite for old Nerves libraries at
https://github.com/nerves-project-attic.

</details>

## Host Requirements

* Mac OS 10.13+ (High Sierra and later)
* 64-bit Linux (tested on Debian / Ubuntu / Redhat / CentOS / Arch)
* Windows 10 with [Windows Subsystem for Linux 2](https://msdn.microsoft.com/en-us/commandline/wsl/install_guide)
* Elixir ~> 1.11

See [Installation Docs](https://hexdocs.pm/nerves/installation.html) for
software dependencies.

## Quick-Reference

### Generating a New Nerves Application

```bash
mix nerves.new my_app
```

### Building Firmware

```bash
export MIX_TARGET=rpi3
mix deps.get      # Fetch the dependencies
mix firmware      # Cross-compile dependencies and create a .fw file
mix firmware.burn # Burn firmware to an inserted SD card
```

**Note:** The `mix firmware.burn` target relies on the presence of `ssh-askpass`. Some
users may need to export the `SUDO_ASKPASS` environment variable to point to their askpass
binary.  On Arch Linux systems, this is in `/usr/lib/ssh/ssh-askpass`

## Docs

[Installation Docs](https://hexdocs.pm/nerves/installation.html)

[Getting Started](https://hexdocs.pm/nerves/getting-started.html)

[Frequently-Asked Questions](https://hexdocs.pm/nerves/faq.html)

[Systems](https://hexdocs.pm/nerves/systems.html)

[Targets](https://hexdocs.pm/nerves/supported-targets.html)

[User Interfaces](https://hexdocs.pm/nerves/user-interfaces.html)

[Advanced Configuration](https://hexdocs.pm/nerves/advanced-configuration.html)

[Compiling non-BEAM code](https://hexdocs.pm/nerves/compiling-non-beam-code.html)

[Customizing Systems](https://hexdocs.pm/nerves/customizing-systems.html)

## Contributors

This project exists thanks to all the people who contribute.
<a href="https://github.com/nerves-project/nerves/graphs/contributors"><img src="https://opencollective.com/nerves-project/contributors.svg?width=890" /></a>

Please see our [Contributing Guide](https://github.com/nerves-project/.github/blob/main/CONTRIBUTING.md) for details on how you can
contribute in various ways.

## Metal Level Sponsors

Metal level sponsors are companies that allow core team members to maintain and
extend Nerves for a portion of each work week. Nerves is not a product of any
one company. We also have a soft spot for supporting makers and hobbyists using
the BEAM, and it would be difficult to do this without them.

<a href="https://www.smartrent.com" target="_blank"><img width="200" height="100" src="https://www.nerves-project.org/hubfs/Very%20Logos%20Smart%20Rent.png"></a>

<a href="https://www.binarynoggin.com" target="_blank"><img width="250" src="https://www.nerves-project.org/assets/BinaryNoggin_logo_250.png"></a>

[[Become a metal level sponsor]](http://nerves-project.org/sponsors)

## OpenCollective Backers

Thank you to all our monetary backers! Hardware costs money and without support,
we wouldn't be able to support nearly as many devices. 🙏 [[Become a
backer](https://opencollective.com/nerves-project#backer)]

<a href="https://opencollective.com/nerves-project#backers" target="_blank"><img src="https://opencollective.com/nerves-project/backers.svg?width=890"></a>

## OpenCollective Sponsors

Support this project by becoming a sponsor. Your logo will show up here with a link to your website. [[Become a sponsor](https://opencollective.com/nerves-project#sponsor)]

<a href="https://opencollective.com/nerves-project/sponsor/0/website" target="_blank"><img src="https://opencollective.com/nerves-project/sponsor/0/avatar.svg"></a>
<a href="https://opencollective.com/nerves-project/sponsor/1/website" target="_blank"><img src="https://opencollective.com/nerves-project/sponsor/1/avatar.svg"></a>
<a href="https://opencollective.com/nerves-project/sponsor/2/website" target="_blank"><img src="https://opencollective.com/nerves-project/sponsor/2/avatar.svg"></a>
<a href="https://opencollective.com/nerves-project/sponsor/3/website" target="_blank"><img src="https://opencollective.com/nerves-project/sponsor/3/avatar.svg"></a>
<a href="https://opencollective.com/nerves-project/sponsor/4/website" target="_blank"><img src="https://opencollective.com/nerves-project/sponsor/4/avatar.svg"></a>
<a href="https://opencollective.com/nerves-project/sponsor/5/website" target="_blank"><img src="https://opencollective.com/nerves-project/sponsor/5/avatar.svg"></a>
<a href="https://opencollective.com/nerves-project/sponsor/6/website" target="_blank"><img src="https://opencollective.com/nerves-project/sponsor/6/avatar.svg"></a>
<a href="https://opencollective.com/nerves-project/sponsor/7/website" target="_blank"><img src="https://opencollective.com/nerves-project/sponsor/7/avatar.svg"></a>
<a href="https://opencollective.com/nerves-project/sponsor/8/website" target="_blank"><img src="https://opencollective.com/nerves-project/sponsor/8/avatar.svg"></a>
<a href="https://opencollective.com/nerves-project/sponsor/9/website" target="_blank"><img src="https://opencollective.com/nerves-project/sponsor/9/avatar.svg"></a>

Copyright (C) 2015-2021 by the Nerves Project developers <nerves@nerves-project.org>
