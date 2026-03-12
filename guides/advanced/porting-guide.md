# Porting Nerves to a New Device

## Who is this guide for?

This guide is for those of you that have a piece of hardware that isn't in the [list of supported targets](https://hexdocs.pm/nerves/supported-targets.html) and on which you want to get Nerves running on it. Maybe it's a old unsupported board, some random SBC you found on AliExpress, or an industrial board your company designs. Whatever it is, if it can run Linux, it can probably run Nerves.

Before you dive in, make sure you're comfortable with the basics of Nerves. If you haven't already, go through the [Getting Started](https://hexdocs.pm/nerves/getting-started.html) guide first. You should also read [The Anatomy of a Nerves System](https://hexdocs.pm/nerves/systems.html) to understand how official systems are structured. This guide picks up where those leave off.

We are going to focus on standard Linux boards, the kind with an SD card slot, U-Boot, and a mainline (or close to mainline) kernel. If your device is different, you might learn a thing or two in this guide, but be advised that it will require more efforts.

## A quick refresher on how Linux boots

Before we get into Nerves specifics, let's make sure we're on the same page about how a Linux system works. Every Linux system, Nerves or not, has three fundamental pieces:

```
+-------------------+    +-------------------+    +-------------------+
|    Bootloader     |    |      Kernel       |    |      Rootfs       |
+-------------------+    +-------------------+    +-------------------+
|                   |    |                   |    |                   |
| Initializes HW    |    | Manages processes |    | Programs,         |
| Loads kernel into |--->| Memory mgmt       |--->| libraries,        |
| memory, starts it |    | Device drivers    |    | config, your app  |
|                   |    | Filesystems       |    |                   |
+-------------------+    +-------------------+    +-------------------+
```

The **bootloader** is the first code that runs when the device powers on. Its only job is to initialize the bare minimum (CPU, RAM, storage controller), find the kernel on disk, load it into memory, and jump to it. Most embedded boards use [U-Boot](https://docs.u-boot.org/en/latest/). You'll also see Barebox on some boards and GRUB on x86_64 systems.

The **kernel** is the core of the operating system. It manages processes, memory, filesystems, networking, and talks to hardware through device drivers. The kernel needs to know about your specific SoC and peripherals, which is described in a **device tree** (DTB), a data structure the bootloader passes to the kernel at boot. Without the right device tree for your board, the kernel might boot but it is likely that nothing will work. A bad device tree can even fry your board in case you mess up voltage regulators configuration for instance...

The **root filesystem** (rootfs) contains everything else: binaries, libraries, configuration files, and your application. The very first userspace process is PID 1, which on a traditional Linux system would be something like `systemd` or BusyBox `init`. On Nerves, it's [erlinit](https://github.com/nerves-project/erlinit). Usually, the kernel tries to find /sbin/init in your rootfs and executes it.

The boot sequence looks like this:

```
Power on → Bootloader → Kernel → mounts rootfs → runs PID 1
```

The bootloader tells the kernel where to find the rootfs through the kernel command line (e.g. `root=/dev/mmcblk0p2`). The kernel mounts it and starts PID 1. Everything else follows from there.

## What Buildroot is and why you need it first

[Buildroot](https://buildroot.org) is a build system that cross-compiles a complete Linux system from source. It takes a configuration file (called a `defconfig`) and produces a kernel, a root filesystem, and optionally a complete disk image. The output is a small, purpose-built system, typically 20 to 60 MB, with only what you asked for.

Nerves uses Buildroot under the hood. The `nerves_system_br` package is essentially a Buildroot [external tree](https://buildroot.org/downloads/manual/manual.html#outside-br-custom) with Nerves-specific packages and configuration.

This is important: **before you try to create a Nerves system for your board, you should have a working Buildroot system first**. A plain Buildroot image that boots, gives you a shell, and proves that the hardware works. If you can't get Buildroot to produce a working image for your board, adding Nerves on top of it from the start will just make things more confusing.

Getting a basic Buildroot system running will force you to solve all the hard problems first: does the kernel support your SoC? Do you have the right device tree? Does the bootloader work? Are there proprietary firmware blobs you need? Once you have answers to all of these, turning it into a Nerves system is mostly mechanical.

## What you need from the device manufacturer

To get started, you need a few things from the manufacturer or from the community:

1. **A kernel that supports your SoC.** Ideally a mainline kernel (from [kernel.org](https://kernel.org)), but a vendor fork or a community fork (like the ones maintained by [Armbian](https://www.armbian.com/) or directly from the board vendor's documentation) works too. Check `arch/arm64/boot/dts/` or `arch/arm/boot/dts/` in the kernel source for a device tree matching your board.

2. **A bootloader.** Usually U-Boot. The manufacturer should include a U-Boot fork with support for your board, or you can check if mainline U-Boot already supports it. It could be that the board manufacturer provides a different bootloader that is not U-Boot.

3. **A working defconfig.** Many SoC vendors provide Buildroot defconfigs for their evaluation boards. Armbian configurations are another great starting point. If your board is already in Buildroot's `configs/` directory (check `ls configs/ | grep your_board`), you're in luck.

4. **Firmware blobs.** Some peripherals (WiFi, Bluetooth, GPU) require proprietary firmware files that the kernel loads at runtime on the peripheral's microcontroller. These usually live in `/lib/firmware/` and you can find them in the [linux-firmware](https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/) repository or in the manufacturer's documentation.

If you're struggling to find any of these, search for your SoC on the following sites, chances are someone has already done the hard work:

- [Armbian](https://www.armbian.com/), great for SBCs, has working kernel configs and U-Boot for hundreds of boards
- [Buildroot defconfigs](https://git.buildroot.net/buildroot/tree/configs), Buildroot ships with configs for many boards out of the box
- [PostmarketOS](https://wiki.postmarketos.org/wiki/Devices), huge database of devices with kernel and device tree info
- Mainline kernel `arch/arm*/boot/dts/`, your SoC might already be supported upstream
- Randomly search for your soc name on github, you might be in luck...

## Getting a Buildroot system running

Once you have a kernel source and a defconfig, the workflow is standard Buildroot:

```bash
# Download Buildroot
git clone https://gitlab.com/buildroot.org/buildroot/
cd buildroot

# If using a built-in defconfig
make <your_board>_defconfig
make

# If using an external tree from the manufacturer
make BR2_EXTERNAL=../my-external my_board_defconfig
make
```

The output lands in `output/images/` and typically includes a kernel image, device tree blob, root filesystem, and sometimes a complete SD card image.

Flash it to an SD card, boot it, get a shell. If it works, great. If it doesn't, you need to debug the Buildroot setup before moving on. Common issues at this stage:

- **Wrong device tree**: The kernel boots but peripherals don't work. Double-check that you're using the exact DTB for your board, not just the SoC family.
- **Missing firmware blobs**: WiFi or other peripherals are silent. Some hardware needs proprietary blobs loaded at runtime.
- **Bootloader can't find the kernel**: This is usually a U-Boot configuration problem. Check the [U-Boot environment variables](https://docs.u-boot.org/en/latest/usage/environment.html), specifically `bootcmd`, `kernel_addr_r`, and `fdt_addr_r`. These control what U-Boot loads and where it loads it to. If your board uses a boot script (`boot.scr`), make sure it's actually on the boot partition and that U-Boot is looking in the right place. The [U-Boot partition syntax](https://docs.u-boot.org/en/latest/usage/partitions.html) (`mmc 0:1`, etc.) trips people up, `0` is the device number and `1` is the partition number, and they don't always map to what you'd expect.
- **U-Boot SPL doesn't start**: On many ARM boards, the boot ROM loads a small first-stage loader (SPL) from a specific offset on the SD card. If it's at the wrong offset, you get nothing, no output, no signs of life. Check the [SPL boot documentation](https://docs.u-boot.org/en/latest/usage/spl_boot.html) for how the TPL → SPL → U-Boot chain works, and look up your SoC in the [board-specific docs](https://docs.u-boot.org/en/latest/board/index.html) (organized by vendor: Allwinner, Amlogic, Rockchip, TI, NXP, etc.) for the exact offset.
- **Wrong kernel command line**: `root=` pointing to the wrong partition, or missing `rootwait` which causes the kernel to panic before the SD card driver is ready. U-Boot passes this through `bootargs`, see the [environment variables reference](https://docs.u-boot.org/en/latest/usage/environment.html) for the full list of standard variables.

#### When in doubt, connect a serial console

Seriously, do it. Find out where the serial console is on your board and fix some wires to it. U-Boot prints detailed messages about what it's trying to load and from where. If you don't have serial output, you're debugging blind. Set `bootdelay` to a few seconds in the U-Boot environment so you can interrupt the boot and poke around interactively. The [U-Boot documentation](https://docs.u-boot.org/en/latest/) is solid, start with your [board's page](https://docs.u-boot.org/en/latest/board/index.html) and work from there.

Once you have a shell on the device and the hardware you care about is functional, you're ready to turn this into a Nerves system.

#### Keep your Buildroot defconfig handy

You'll need the Buildroot defconfig and the kernel config from your working system. If you built from scratch, save them now:

```bash
# In your Buildroot build directory
make savedefconfig        # saves to defconfig
make linux-update-defconfig  # saves kernel config
```

#### Take note of any init scripts your board needs

Before you move on, pay attention to what your Buildroot system is doing at startup to make the hardware work. Many boards have init scripts that load firmware or bring up specific peripherals. In a standard Linux system, these run as shell scripts in `/etc/init.d/` or as systemd services.

Nerves doesn't have init scripts. There's no shell running at boot, no init system handling services lifecycle. If your board needs something to happen at startup for the hardware to work, you'll need to handle it from your Elixir application, typically as an OTP application that runs the necessary setup when it starts. Things like loading a firmware blob or toggling a GPIO to enable a peripheral are straightforward to do from Elixir using libraries like [Circuits.GPIO](https://hexdocs.pm/circuits_gpio/) or by calling into a small C port program.

Make a list of what those scripts do now. You'll need them later.

## Creating a new Nerves system

A Nerves system is an Elixir project that wraps a Buildroot external tree. If you've read [The Anatomy of a Nerves System](https://hexdocs.pm/nerves/systems.html), you know that the official systems like `nerves_system_rpi5` are just Mix projects with some specific files. Here's what a complete Nerves system looks like:

```
nerves_system_my_board/
├── mix.exs                     # Elixir project, depends on nerves_system_br + toolchain
├── nerves_defconfig            # Buildroot defconfig with Nerves-specific settings
├── linux-X.Y.defconfig         # Kernel config
├── fwup.conf                   # Firmware creation and flashing rules
├── fwup-ops.conf               # Runtime operations (revert, validate, etc.)
├── fwup_include/
│   ├── fwup-common.conf        # Partition layout definitions
│   └── provisioning.conf       # Device serial number provisioning
├── post-build.sh               # Buildroot post-build hook
├── post-createfs.sh            # Post-createfs hook
├── rootfs_overlay/
│   └── etc/
│       ├── erlinit.config      # PID 1 configuration
│       ├── fw_env.config       # U-Boot environment access from Linux
│       └── boardid.config      # Board identification
├── uboot/
│   └── boot.cmd                # U-Boot boot script (compiled to boot.scr)
├── Config.in                   # Custom Buildroot packages menu
├── external.mk                 # Custom packages Makefile includes
└── VERSION                     # System version
```

Let's go through what each of these files does and how to create them.

### mix.exs

The `mix.exs` is a standard Elixir project file. The key things are:

- It depends on `nerves_system_br` (the Buildroot platform)
- It depends on a Nerves toolchain package for your architecture
- It declares a `nerves_package` configuration with `:type`, `:platform`, and `:checksum`

Here's a minimal example for an AArch64 board:

```elixir
defmodule NervesSystemMyBoard.MixProject do
  use Mix.Project

  @github_organization "your-github-user"
  @app :nerves_system_my_board
  @version Path.join(__DIR__, "VERSION")
           |> File.read!()
           |> String.trim()

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.17",
      compilers: Mix.compilers() ++ [:nerves_package],
      nerves_package: nerves_package(),
      deps: deps(),
      aliases: [loadconfig: [&bootstrap/1]],
      docs: [extras: ["README.md", "CHANGELOG.md"], main: "readme"]
    ]
  end

  defp bootstrap(args) do
    System.put_env("MIX_TARGET", "my_board")
    Application.start(:nerves_bootstrap)
    Mix.Task.run("loadconfig", args)
  end

  defp nerves_package do
    [
      type: :system,
      artifact_sites: [
        {:github_releases, "#{@github_organization}/#{@app}"}
      ],
      platform: Nerves.System.BR,
      platform_config: [
        defconfig: "nerves_defconfig"
      ],
      checksum: package_files()
    ]
  end

  defp deps do
    [
      {:nerves, "~> 1.10", runtime: false},
      {:nerves_system_br, "~> 1.28", runtime: false},
      {:nerves_toolchain_aarch64_nerves_linux_gnu, "~> 13.2.0", runtime: false}
    ]
  end

  defp package_files do
    [
      "nerves_defconfig",
      "rootfs_overlay",
      "linux-6.6.defconfig",
      "fwup.conf",
      "fwup-ops.conf",
      "fwup_include",
      "post-build.sh",
      "post-createfs.sh",
      "uboot",
      "VERSION"
    ]
  end
end
```

The toolchain dependency is where you choose which cross-compiler will be used. More on that in the next section.

Instead of creating these files manually, you can start from and existing supported system and change what doesn't fit your board.

#### About `nerves_package` configuration

The `nerves_package` configuration tells Nerves how to build and distribute your system. The `:checksum` list is important, it defines which files are used to determine if the system needs to be rebuilt. If you add a new file to your system, make sure to include it here. For more details, see the [Nerves Package Configuration](https://hexdocs.pm/nerves/systems.html#nerves-package-configuration) documentation.

### Choosing a toolchain

Nerves provides prebuilt toolchain packages for a range of architectures. You pick the one that matches your target. The full list is available at [github.com/nerves-project/toolchains](https://github.com/nerves-project/toolchains/releases), but here are the most common ones:

| Architecture                 | Toolchain package                               | Typical use                   |
| :--------------------------- | :---------------------------------------------- | :---------------------------- |
| ARM 64-bit (AArch64)         | `nerves_toolchain_aarch64_nerves_linux_gnu`     | Pine64, most modern ARM SBCs  |
| ARM 32-bit v7, hard float    | `nerves_toolchain_armv7_nerves_linux_gnueabihf` | BeagleBone, RPi 2/3 (32-bit)  |
| ARM 32-bit v6, hard float    | `nerves_toolchain_armv6_nerves_linux_gnueabihf` | RPi Zero, RPi 1               |
| x86_64                       | `nerves_toolchain_x86_64_nerves_linux_musl`     | Generic x86_64 / QEMU         |
| RISC-V 64-bit                | `nerves_toolchain_riscv64_nerves_linux_gnu`     | MangoPi MQ-Pro, etc.          |

How do you know which one to pick? Look at the `BR2_` architecture options in your working Buildroot defconfig:

- `BR2_aarch64=y` → `aarch64_nerves_linux_gnu`
- `BR2_arm=y` with an ARMv7 core → `armv7_nerves_linux_gnueabihf`
- `BR2_arm=y` with an ARMv6 core (like BCM2835) → `armv6_nerves_linux_gnueabihf`
- `BR2_x86_64=y` → `x86_64_nerves_linux_musl`
- `BR2_riscv=y` → `riscv64_nerves_linux_gnu`

## Moving your kernel config to Nerves

Take the kernel defconfig from your working Buildroot system and copy it into your Nerves system directory. Name it `linux-X.Y.defconfig` where X.Y matches your kernel version (e.g. `linux-6.6.defconfig`).

You need to add a few kernel options that Nerves requires. These enable the filesystem formats and USB networking that Nerves depends on:

```
# Required for the Nerves read-only root filesystem
CONFIG_SQUASHFS=y
CONFIG_SQUASHFS_LZ4=y

# Required for the application data partition
CONFIG_F2FS_FS=y

# Required for USB gadget networking (console access over USB)
CONFIG_USB_GADGET=y
CONFIG_USB_ETH=y
```

If any of these are already enabled in your config (possibly as modules `=m`), make sure they're set to `=y` (built-in). Nerves needs them available at boot, not as loadable modules.

#### Verifying your kernel config

You can check if these options are already set by grepping your defconfig:

```bash
grep -E "SQUASHFS|F2FS|USB_GADGET|USB_ETH" linux-6.6.defconfig
```

If they're missing entirely, just append them. If they're set to `=m`, change them to `=y`. Buildroot's `make linux-menuconfig` and `make linux-update-defconfig` are your friends here.

## Creating the nerves_defconfig

This is where the real work happens. The `nerves_defconfig` is a Buildroot defconfig with Nerves-specific settings baked in. You're going to take your working Buildroot defconfig and transform it.

### What to remove

A bunch of things from your original defconfig are handled by `nerves_system_br` and should be removed. Strip out anything that starts with these prefixes:

| Option                                                     | Why remove it                                              |
| :--------------------------------------------------------- | :--------------------------------------------------------- |
| `BR2_TOOLCHAIN_*`                                          | Nerves provides its own external toolchain                 |
| `BR2_INIT_*`                                               | Nerves uses `erlinit`, not busybox init or systemd         |
| `BR2_SYSTEM_BIN_SH_*`                                      | Shell configuration is handled by Nerves                   |
| `BR2_TARGET_GENERIC_HOSTNAME`                              | Nerves sets its own hostname                               |
| `BR2_TARGET_GENERIC_ISSUE`                                 | Not needed                                                 |
| `BR2_TARGET_GENERIC_PASSWD_*`                              | Not needed                                                 |
| `BR2_TARGET_GENERIC_GETTY*`                                | No getty in Nerves                                         |
| `BR2_SYSTEM_DHCP`                                          | Networking is handled by VintageNet in Elixir              |
| `BR2_TARGET_ROOTFS_*`                                      | Nerves configures squashfs                                 |
| `BR2_PACKAGE_BUSYBOX_CONFIG`                               | Nerves provides its own busybox config                     |
| `BR2_ROOTFS_SKELETON_*`                                    | Nerves uses a custom skeleton                              |
| `BR2_ROOTFS_OVERLAY`                                       | Nerves sets its own overlays                               |
| `BR2_ROOTFS_POST_BUILD_SCRIPT`                             | Nerves has its own post-build hooks                        |
| `BR2_ROOTFS_POST_IMAGE_SCRIPT`                             | Same                                                       |
| `BR2_ROOTFS_POST_SCRIPT_ARGS`                              | Same                                                       |
| `BR2_ROOTFS_DEVICE_TABLE`                                  | Not needed                                                 |
| `BR2_TARGET_OPTIMIZATION`                                  | Handled by the toolchain                                   |
| `BR2_BACKUP_SITE`                                          | Not needed                                                 |
| `BR2_ENABLE_DEBUG`                                         | Not needed                                                 |
| `BR2_GLOBAL_PATCH_DIR`                                     | Handled differently in Nerves                              |
| `BR2_REPRODUCIBLE`                                         | Not needed                                                 |
| `BR2_ENABLE_LOCALE_*`                                      | Not needed                                                 |
| `BR2_GENERATE_LOCALE`                                      | Not needed                                                 |
| `BR2_DOWNLOAD_FORCE_CHECK_HASHES`                          | Not needed                                                 |
| `BR2_TAR_OPTIONS`                                          | Not needed                                                 |

What you should **keep** is everything specific to your board: the architecture settings (`BR2_arm=y`, `BR2_cortex_a53=y`, etc.), kernel configuration, U-Boot configuration, any board-specific packages, and device-specific options. It could be that some of the options listed above are critical for your board, and it that case you should of course keep them.

### What to add

After stripping out the Nerves-incompatible settings, add the following blocks. These configure the Nerves toolchain, init system, root filesystem, and required packages.

**Toolchain** (replace the URL and headers version with the right values for your architecture):

```
BR2_TOOLCHAIN_EXTERNAL=y
BR2_TOOLCHAIN_EXTERNAL_CUSTOM=y
BR2_TOOLCHAIN_EXTERNAL_DOWNLOAD=y
BR2_TOOLCHAIN_EXTERNAL_URL="https://github.com/nerves-project/toolchains/releases/download/v13.2.0/nerves_toolchain_aarch64_nerves_linux_gnu-linux_x86_64-13.2.0-B21A7B8.tar.xz"
BR2_TOOLCHAIN_EXTERNAL_CUSTOM_PREFIX="aarch64-nerves-linux-gnu"
BR2_TOOLCHAIN_EXTERNAL_GCC_13=y
BR2_TOOLCHAIN_EXTERNAL_HEADERS_5_4=y
BR2_TOOLCHAIN_EXTERNAL_CUSTOM_GLIBC=y
BR2_TOOLCHAIN_EXTERNAL_CXX=y
BR2_TOOLCHAIN_EXTERNAL_FORTRAN=y
BR2_TOOLCHAIN_EXTERNAL_OPENMP=y
```

#### Finding the right toolchain URL

Go to [github.com/nerves-project/toolchains/releases](https://github.com/nerves-project/toolchains/releases), find the latest release, and grab the URL for the tarball matching your architecture and host platform (usually `linux_x86_64`). The `BR2_TOOLCHAIN_EXTERNAL_CUSTOM_PREFIX` must match the toolchain's prefix, for AArch64 that's `aarch64-nerves-linux-gnu`, for ARMv7 it's `armv7-nerves-linux-gnueabihf`, and so on.

**Init system and skeleton:**

```
BR2_INIT_NONE=y
BR2_ROOTFS_SKELETON_CUSTOM=y
BR2_ROOTFS_SKELETON_CUSTOM_PATH="${BR2_EXTERNAL_NERVES_PATH}/board/nerves-common/skeleton"
```

Nerves doesn't use a traditional init system. `erlinit` is PID 1 and starts the BEAM VM directly. The custom skeleton is a minimal directory structure provided by `nerves_system_br`.

**Root filesystem:**

```
BR2_TARGET_ROOTFS_SQUASHFS=y
BR2_TARGET_ROOTFS_SQUASHFS_LZ4=y
```

Nerves uses a read-only squashfs root filesystem compressed with LZ4. This is non-negotiable, the whole OTA update mechanism depends on it.

**Nerves meta-package and Busybox:**

```
BR2_PACKAGE_NERVES_CONFIG=y
BR2_PACKAGE_BUSYBOX_CONFIG="${BR2_EXTERNAL_NERVES_PATH}/board/nerves-common/busybox.config"
```

`BR2_PACKAGE_NERVES_CONFIG` is a meta-package defined in `nerves_system_br` that pulls in everything Nerves needs. We'll look at what it includes in a later section.

**Post-build hooks and overlays:**

```
BR2_ROOTFS_OVERLAY="${BR2_EXTERNAL_NERVES_PATH}/board/nerves-common/rootfs_overlay ${NERVES_DEFCONFIG_DIR}/rootfs_overlay"
BR2_ROOTFS_POST_BUILD_SCRIPT="${BR2_EXTERNAL_NERVES_PATH}/board/nerves-common/post-build.sh ${NERVES_DEFCONFIG_DIR}/post-build.sh"
BR2_ROOTFS_POST_SCRIPT_ARGS="${NERVES_DEFCONFIG_DIR}"
```

Notice the use of `${BR2_EXTERNAL_NERVES_PATH}` and `${NERVES_DEFCONFIG_DIR}`. These are variables that Buildroot resolves at build time:

- `BR2_EXTERNAL_NERVES_PATH` points to the `nerves_system_br` directory
- `NERVES_DEFCONFIG_DIR` points to your system's directory (where `nerves_defconfig` lives)

The overlays are applied in order: first the common Nerves overlay, then your system-specific one. Same for post-build scripts.

**Kernel configuration pointer:**

```
BR2_LINUX_KERNEL_CUSTOM_CONFIG_FILE="${NERVES_DEFCONFIG_DIR}/linux-6.6.defconfig"
```

Make sure this matches the filename of the kernel config you created earlier.

### A complete example

Here's what a real `nerves_defconfig` looks like for an AArch64 Allwinner board (like a Pine64). The board-specific parts are at the top, then the Nerves additions:

```
# Architecture
BR2_aarch64=y
BR2_cortex_a53=y

# Toolchain (Nerves external)
BR2_TOOLCHAIN_EXTERNAL=y
BR2_TOOLCHAIN_EXTERNAL_CUSTOM=y
BR2_TOOLCHAIN_EXTERNAL_DOWNLOAD=y
BR2_TOOLCHAIN_EXTERNAL_URL="https://github.com/nerves-project/toolchains/releases/download/v13.2.0/nerves_toolchain_aarch64_nerves_linux_gnu-linux_x86_64-13.2.0-B21A7B8.tar.xz"
BR2_TOOLCHAIN_EXTERNAL_CUSTOM_PREFIX="aarch64-nerves-linux-gnu"
BR2_TOOLCHAIN_EXTERNAL_GCC_13=y
BR2_TOOLCHAIN_EXTERNAL_HEADERS_5_4=y
BR2_TOOLCHAIN_EXTERNAL_CUSTOM_GLIBC=y
BR2_TOOLCHAIN_EXTERNAL_CXX=y
BR2_TOOLCHAIN_EXTERNAL_FORTRAN=y
BR2_TOOLCHAIN_EXTERNAL_OPENMP=y

# System
BR2_INIT_NONE=y
BR2_ROOTFS_SKELETON_CUSTOM=y
BR2_ROOTFS_SKELETON_CUSTOM_PATH="${BR2_EXTERNAL_NERVES_PATH}/board/nerves-common/skeleton"
BR2_NERVES_SYSTEM_NAME="nerves_system_my_board"

# Kernel
BR2_LINUX_KERNEL=y
BR2_LINUX_KERNEL_USE_CUSTOM_CONFIG=y
BR2_LINUX_KERNEL_CUSTOM_CONFIG_FILE="${NERVES_DEFCONFIG_DIR}/linux-6.6.defconfig"
BR2_LINUX_KERNEL_DTS_SUPPORT=y
BR2_LINUX_KERNEL_INTREE_DTS_NAME="allwinner/sun50i-a64-pine64-plus"

# U-Boot
BR2_TARGET_UBOOT=y
BR2_TARGET_UBOOT_BUILD_SYSTEM_KCONFIG=y
BR2_TARGET_UBOOT_CUSTOM_VERSION=y
BR2_TARGET_UBOOT_CUSTOM_VERSION_VALUE="2024.04"
BR2_TARGET_UBOOT_BOARD_DEFCONFIG="pine64_plus"

# Packages
BR2_PACKAGE_NERVES_CONFIG=y
BR2_PACKAGE_BUSYBOX_CONFIG="${BR2_EXTERNAL_NERVES_PATH}/board/nerves-common/busybox.config"
BR2_PACKAGE_NBTTY=y
BR2_PACKAGE_CA_CERTIFICATES=y

# Root filesystem
BR2_TARGET_ROOTFS_SQUASHFS=y
BR2_TARGET_ROOTFS_SQUASHFS_LZ4=y

# Build hooks
BR2_ROOTFS_OVERLAY="${BR2_EXTERNAL_NERVES_PATH}/board/nerves-common/rootfs_overlay ${NERVES_DEFCONFIG_DIR}/rootfs_overlay"
BR2_ROOTFS_POST_BUILD_SCRIPT="${BR2_EXTERNAL_NERVES_PATH}/board/nerves-common/post-build.sh ${NERVES_DEFCONFIG_DIR}/post-build.sh"
BR2_ROOTFS_POST_SCRIPT_ARGS="${NERVES_DEFCONFIG_DIR}"
```

## Setting up fwup.conf

[fwup](https://github.com/fhunleth/fwup) is the tool Nerves uses to create firmware images, burn them to SD cards, and perform OTA updates. The `fwup.conf` file describes the partition layout and defines tasks for creating and upgrading firmware.

This is the part that varies the most between boards, because partition layouts differ depending on the bootloader and storage type.

### The standard MBR partition layout

Most ARM boards with U-Boot and an SD card use something like this:

```
+----------+--------+----------+----------+-------------+-----------+
| U-Boot   | Boot A | Boot B   | Rootfs A | Rootfs B    | App data  |
| env      | (FAT)  | (FAT)    | (squash) | (squash)    | (F2FS)    |
+----------+--------+----------+----------+-------------+-----------+
```

The first region is the U-Boot environment, a small key/value store that Nerves uses to track firmware metadata (active boot slot, firmware validation status, etc.). Even on platforms that don't actually use U-Boot as their bootloader, Nerves still uses this format as a convenient persistent key/value store.

After that come the real partitions: two boot slots (FAT32, holding the kernel, device tree, and boot script), two rootfs slots (read-only squashfs), and an application data partition (F2FS, writable). The dual A/B scheme is what makes Nerves OTA updates safe: the running system is on slot A, the update goes to slot B, and if the update fails, you can fall back to slot A. The `fwup.conf` defines the tasks that implement this.

On many boards, U-Boot itself lives on the FAT32 boot partition alongside the kernel and device tree, so it doesn't need its own raw region on disk.

#### What about boards with U-Boot SPL?

Some SoCs (Allwinner, Rockchip, some TI and NXP parts) require U-Boot to be raw-written at a specific offset on the SD card, before any partitions. On these boards, the boot ROM looks for a first-stage loader (SPL) at a hardcoded location. The layout then looks like this:

```
+---------+----------+--------+----------+----------+-------------+-----------+
| U-Boot  | U-Boot   | Boot A | Boot B   | Rootfs A | Rootfs B    | App data  |
| SPL     | env      | (FAT)  | (FAT)    | (squash) | (squash)    | (F2FS)    |
+---------+----------+--------+----------+----------+-------------+-----------+
```

The exact offset depends on the SoC. For Allwinner, U-Boot's SPL goes at block 16 (8 KiB offset). For other SoCs, it might be at block 2, block 8, or somewhere else entirely. Check your board's page in the [U-Boot board-specific documentation](https://docs.u-boot.org/en/latest/board/index.html) for the exact layout. If you're not sure whether your board needs raw U-Boot writes, look at how the manufacturer's documentation explains it or how Armbian handles it if your board is supported there.

### The partition definition file

The actual partition offsets and sizes go in `fwup_include/fwup-common.conf`. Here's an example for the standard layout (no raw U-Boot on disk):

```
# Firmware partition definitions

# Let fwup know the image is for an SD card
define(NERVES_FW_DEVPATH, "/dev/mmcblk0")

# U-Boot environment (small key/value store before the partitions)
define(UBOOT_ENV_OFFSET, 16)
define(UBOOT_ENV_COUNT, 16)

# Boot A partition (FAT32, holds kernel + DTB + boot.scr)
define(BOOT_A_PART_OFFSET, 63)
define(BOOT_A_PART_COUNT, 65536)

# Boot B partition
define-eval(BOOT_B_PART_OFFSET, "${BOOT_A_PART_OFFSET} + ${BOOT_A_PART_COUNT}")
define(BOOT_B_PART_COUNT, 65536)

# Rootfs A partition (squashfs)
define-eval(ROOTFS_A_PART_OFFSET, "${BOOT_B_PART_OFFSET} + ${BOOT_B_PART_COUNT}")
define(ROOTFS_A_PART_COUNT, 524288)

# Rootfs B partition
define-eval(ROOTFS_B_PART_OFFSET, "${ROOTFS_A_PART_OFFSET} + ${ROOTFS_A_PART_COUNT}")
define(ROOTFS_B_PART_COUNT, 524288)

# Application data partition (F2FS, fills the rest)
define-eval(APP_PART_OFFSET, "${ROOTFS_B_PART_OFFSET} + ${ROOTFS_B_PART_COUNT}")
define(APP_PART_COUNT, 0)
define(NERVES_FW_APPLICATION_PART0_DEVPATH, "/dev/mmcblk0p3")
define(NERVES_FW_APPLICATION_PART0_FSTYPE, "f2fs")
define(NERVES_FW_APPLICATION_PART0_TARGET, "/data")
```

All values are in 512-byte blocks. So `65536` blocks = 32 MiB. Notice the offsets chain together using `define-eval`, you only need to set the first offset and the sizes, and everything else follows.

You might be wondering why the app partition is `mmcblk0p3` when there are clearly more than 3 regions on disk. That's because the U-Boot env and the raw U-Boot binary (if any) live *before* the MBR partition table and aren't real partitions. Nerves uses only 3 MBR entries: one for the active boot slot, one for the active rootfs slot, and one for the app data. During an OTA update, fwup rewrites the MBR to swap which physical regions partition 1 and 2 point to, that's the A/B slot switching mechanism.

#### GPT layouts for x86_64

If you're targeting x86_64 with UEFI boot, you'll use a GPT partition table instead of MBR, and the boot partition will be an EFI System Partition. The fwup config is similar but uses GPT-specific commands. Check the [nerves_system_x86_64](https://github.com/nerves-project/nerves_system_x86_64) for an example.

### The main fwup.conf

The main `fwup.conf` includes the partition definitions and defines tasks. The two most important tasks are `complete` (write everything from scratch) and `upgrade` (update the inactive slot).

Here's a simplified example:

```
require-fwup-version="1.0.0"

# Include partition layout
include("fwup_include/fwup-common.conf")

# Firmware metadata
meta-product = "My Board Nerves Image"
meta-description = "Nerves firmware for My Board"
meta-version = ${NERVES_FW_VERSION}
meta-platform = "my_board"
meta-architecture = "aarch64"
meta-author = "Your Name"

# File resources - these are files that get packed into the .fw bundle
file-resource bootpart.vfat {
    host-path = "${NERVES_SYSTEM}/images/bootpart.vfat"
}
file-resource rootfs.img {
    host-path = "${NERVES_SYSTEM}/images/rootfs.squashfs"
}

# Task: complete - write everything to a blank SD card
task complete {
    on-init {
        mbr_write(mbr-a)
        fat_mkfs(${BOOT_A_PART_OFFSET}, ${BOOT_A_PART_COUNT})
        fat_mkfs(${BOOT_B_PART_OFFSET}, ${BOOT_B_PART_COUNT})
    }

    on-resource bootpart.vfat {
        raw_write(${BOOT_A_PART_OFFSET})
    }

    on-resource rootfs.img {
        raw_write(${ROOTFS_A_PART_OFFSET})
    }

    on-finish {
        # Initialize the application data partition
        raw_memset(${APP_PART_OFFSET}, 256, 0xff)
    }
}

# Task: upgrade - update the inactive slot
task upgrade.a {
    # Upgrade B -> A
    require-partition1-offset = ${BOOT_B_PART_OFFSET}

    on-resource bootpart.vfat {
        raw_write(${BOOT_A_PART_OFFSET})
    }

    on-resource rootfs.img {
        raw_write(${ROOTFS_A_PART_OFFSET})
    }

    on-finish {
        mbr_write(mbr-a)
    }
}

task upgrade.b {
    # Upgrade A -> B
    require-partition1-offset = ${BOOT_A_PART_OFFSET}

    on-resource bootpart.vfat {
        raw_write(${BOOT_B_PART_OFFSET})
    }

    on-resource rootfs.img {
        raw_write(${ROOTFS_B_PART_OFFSET})
    }

    on-finish {
        mbr_write(mbr-b)
    }
}
```

This is simplified. Real fwup configs also handle U-Boot environment writes, provisioning, and validation. The best approach is to look at an existing official system that's close to your board and adapt it. The [nerves_system_bbb](https://github.com/nerves-project/nerves_system_bbb) (BeagleBone) is a clean example for MBR-based U-Boot systems.

#### The fwup-ops.conf file

In addition to `fwup.conf`, you'll want a `fwup-ops.conf` that defines runtime operations: reverting to the previous firmware, factory reset, validation, and status queries. These are used by [nerves_runtime](https://hexdocs.pm/nerves_runtime) when your Elixir application calls functions like `Nerves.Runtime.revert/0`. Again, start from an existing system and adapt.

## What nerves_system_br provides

When you set `BR2_PACKAGE_NERVES_CONFIG=y` in your `nerves_defconfig`, you're enabling a meta-package from `nerves_system_br` that selects all the packages Nerves needs to function. Understanding what it pulls in helps you debug issues and know what's available to you.

Here's what `nerves-config` selects:

| Package                          | What it does                                                        |
| :--------------------------------| :------------------------------------------------------------------ |
| **erlang**                       | The BEAM VM and OTP, this is what runs your Elixir application      |
| **erlinit**                      | Replacement for `/sbin/init`. Runs as PID 1, starts the BEAM        |
| **fwup**                         | Firmware update tool, used for OTA updates from within Elixir       |
| **host-fwup**                    | Host-side fwup, used during the build to create `.fw` files         |
| **openssl**                      | Required for Erlang's `:crypto` module                              |
| **ncurses**                      | Required for IEx to work properly (terminal handling)               |
| **nerves_heart**                 | Replaces Erlang's `heart` with one that supports hardware watchdogs |
| **uboot-tools**                  | `fw_printenv`/`fw_setenv`, access U-Boot env from Linux             |
| **boardid**                      | Reads a unique board identifier (serial number, MAC address, etc.)  |
| **rng-tools**                    | `rngd`, required for cryptographic random number generation         |
| **squashfs**                     | Enabled via `BR2_TARGET_ROOTFS_SQUASHFS`, the rootfs format         |

In addition to these, most systems also enable:

- **nbtty**, runs a program in a detached pseudo-terminal, used for the IEx console
- **ca-certificates**, root CA certificates for HTTPS connections

`nerves_system_br` also provides:

- A **custom skeleton** (`board/nerves-common/skeleton/`), a minimal directory structure without the usual Linux cruft. No `/etc/init.d/`, no `/etc/fstab`, no shell profiles.
- A **common rootfs overlay** (`board/nerves-common/rootfs_overlay/`), adds Erlang DNS resolver config, sysctl settings, and filesystem creation defaults.
- A **post-build script** (`board/nerves-common/post-build.sh`), generates `/usr/lib/os-release` with Nerves version info and runs a scrub script that removes shell scripts, init configs, and other files that don't belong in a Nerves system.
- A **busybox config**, a stripped-down busybox with minimal commands. Nerves doesn't want you using shell scripts, but some basic utilities are still useful for debugging.

## The rootfs_overlay directory

Your system's `rootfs_overlay/` directory contains files that get copied into the root filesystem during the build. This is where you put your system-specific configuration.

### erlinit.config

This is the configuration for erlinit, the PID 1 process that starts the BEAM. A typical one looks like:

```
# erlinit.config for my_board
-v

# Console TTY
--ctty ttyS0

# Hostname
--hostname nerves

# Use nbtty for the console
--pre-run-exec /usr/bin/nbtty

# Mount the application data partition
--mount /dev/mmcblk0p3:/data:f2fs::
```

The `--ctty` flag sets the console TTY. This depends on your board, `ttyS0` is common for boards with a UART debug port, `ttyAMA0` for some ARM boards, `tty1` for HDMI output.

The `--mount` flag tells erlinit to mount the application data partition. The path must match what you defined in `fwup-common.conf`.

### fw_env.config

This tells the `fw_printenv`/`fw_setenv` tools where to find the U-Boot environment on disk:

```
/dev/mmcblk0 0x100000 0x20000
```

The format is: device, offset, size. The offset must match where you placed the U-Boot environment in your fwup partition layout.

### boardid.config

Configuration for the `boardid` tool, which reads a unique identifier for the board:

```
# Try reading the serial number from different sources
-b uboot_env -u nerves_serial_number
-b cpuinfo -f Serial
```

## Telling the bootloader how to boot Nerves

The bootloader needs to know where to find the kernel, what device tree to use, and what kernel command line to pass. How you configure this depends entirely on what bootloader your board uses. There are a few common approaches:

### U-Boot with a boot script (most ARM boards)

This is the most common case for custom ARM and ARM64 boards. You write a `boot.cmd` file that U-Boot executes on every boot. It gets compiled to a binary `boot.scr` using `mkimage`, and placed on the FAT32 boot partition.

The variables used here, `kernel_addr_r`, `fdt_addr_r`, `bootargs`, are standard [U-Boot environment variables](https://docs.u-boot.org/en/latest/usage/environment.html). Here's an example for an Allwinner AArch64 board:

```
# boot.cmd - U-Boot boot script for Nerves

# Set boot arguments
setenv bootargs console=ttyS0,115200 root=/dev/mmcblk0p2 rootfstype=squashfs rootwait

# Load kernel and DTB from the active boot partition
fatload mmc 0 ${kernel_addr_r} Image
fatload mmc 0 ${fdt_addr_r} sun50i-a64-pine64-plus.dtb

# Boot
booti ${kernel_addr_r} - ${fdt_addr_r}
```

The `fatload mmc 0` syntax means "load from the FAT filesystem on MMC device 0", see the [U-Boot partition documentation](https://docs.u-boot.org/en/latest/usage/partitions.html) if you need to understand device and partition numbering. The `root=` parameter must point to the correct rootfs partition. In the A/B scheme, fwup rewrites the MBR to swap which physical regions partition 2 points to, so `mmcblk0p2` always refers to the active rootfs.

The boot command at the end (`booti`, `bootz`, or `bootm`) depends on the kernel image format:
- `booti` -for uncompressed `Image` (AArch64, RISC-V)
- `bootz` -for compressed `zImage` (32-bit ARM)
- `bootm` -for legacy uImage format

This `.cmd` file needs to be compiled to a `.scr` file using `mkimage` during the build. Your `post-build.sh` script handles this (we'll get to that shortly).

### U-Boot with extlinux.conf (x86_64, some ARM boards)

Some U-Boot configurations support the [distroboot](https://docs.u-boot.org/en/latest/develop/distro.html) mechanism, which looks for an `extlinux/extlinux.conf` file on the boot partition instead of a boot script. This is common on x86_64 boards and some newer ARM boards. The format is simple:

```
DEFAULT nerves
TIMEOUT 0

LABEL nerves
    LINUX /bzImage
    APPEND root=/dev/sda2 rootfstype=squashfs rootwait console=ttyS0,115200
```

If your U-Boot is configured for distroboot, you don't need a `boot.cmd` at all. Just place the `extlinux.conf` in the right spot on the boot partition. Whether your board uses this approach depends on the U-Boot configuration. Check the `CONFIG_DISTRO_DEFAULTS` or `CONFIG_BOOTCOMMAND` settings in your U-Boot config.

### Raspberry Pi (proprietary bootloader)

The Raspberry Pi doesn't use U-Boot at all. It has its own proprietary boot chain: the VideoCore GPU firmware (`start4.elf`, `fixup4.dat`) reads a `config.txt` and `cmdline.txt` from the FAT boot partition. The kernel command line goes in `cmdline.txt`, and hardware configuration (UART, overlays, GPU memory split) goes in `config.txt`. If you're porting to an RPi, you won't need a boot script, check the [official Raspberry Pi documentation](https://www.raspberrypi.com/documentation/computers/config_txt.html) for the config.txt format.

### U-Boot with FIT images

Some boards use [FIT images](https://docs.u-boot.org/en/latest/usage/fit/index.html) instead of separate kernel and DTB files. FIT bundles the kernel, device tree, and optionally an initramfs into a single signed image. If your board requires FIT, the boot script and post-build steps will be different. Check the board's existing U-Boot configuration to see what it expects.

### U-Boot environment variables only (no script)

On some boards, you can configure U-Boot's persistent environment variables directly (via `bootcmd`, `bootargs`, etc.) and skip the boot script entirely. This works, but it's less portable and harder to version-control. A `boot.cmd` checked into your system repo is generally the better approach for Nerves since it's explicit and reproducible.

## The post-build scripts

### post-build.sh

Your system-specific post-build script runs after Buildroot finishes building the root filesystem but before the image is created. A typical one:

```bash
#!/usr/bin/env bash

set -e

NERVES_DEFCONFIG_DIR="$2"

# Compile U-Boot boot script
"$HOST_DIR/bin/mkimage" -A arm64 -T script -C none \
    -d "$NERVES_DEFCONFIG_DIR/uboot/boot.cmd" \
    "$BINARIES_DIR/boot.scr"

# Create the boot partition image
"$HOST_DIR/bin/mkfs.vfat" -n BOOT -F 32 -S 512 -C "$BINARIES_DIR/bootpart.vfat" 32768
"$HOST_DIR/bin/mcopy" -i "$BINARIES_DIR/bootpart.vfat" -s "$BINARIES_DIR/boot.scr" ::
"$HOST_DIR/bin/mcopy" -i "$BINARIES_DIR/bootpart.vfat" -s "$BINARIES_DIR/Image" ::
"$HOST_DIR/bin/mcopy" -i "$BINARIES_DIR/bootpart.vfat" -s "$BINARIES_DIR/sun50i-a64-pine64-plus.dtb" ::
```

This script compiles the U-Boot boot command into a `boot.scr`, creates a FAT partition image, and copies the kernel, device tree, and boot script into it. The FAT image is what fwup writes to the boot partition.

### post-createfs.sh

This script runs after the root filesystem image is created. It typically just calls the common Nerves post-createfs script:

```bash
#!/bin/sh

set -e

${BR2_EXTERNAL_NERVES_PATH}/board/nerves-common/post-createfs.sh "$1" "$2"
```

## The Config.in and external.mk files

These files exist to allow your system to define custom Buildroot packages. If you don't have any custom packages, they can be minimal:

**Config.in:**
```
# Custom packages for my_board
#
# Add package Config.in sources here if needed
```

**external.mk:**
```
# Include custom packages
# include $(sort $(wildcard $(NERVES_DEFCONFIG_DIR)/packages/*/*.mk))
```

If you later need to add a custom Buildroot package (say, a proprietary binary or a driver not in Buildroot), this is where you'd wire it in. See the [Adding a custom Buildroot Package](https://hexdocs.pm/nerves/customizing-systems.html#adding-a-custom-buildroot-package) section of the official docs for the details.

## Building your system

Once you have all the files in place, building your Nerves system works like any other. From your system directory:

```bash
mix deps.get
mix compile
```

The first build takes a while (15-30 minutes or more) since Buildroot is compiling everything from source. The next builds should much faster unless you run `make clean`.

Once your system compiles, you can use it from a Nerves application project by pointing to it as a path dependency:

```elixir
# In your application's mix.exs
defp deps do
  [
    # ...
    {:nerves_system_my_board, path: "../nerves_system_my_board",
     runtime: false, targets: :my_board, nerves: [compile: true]}
  ]
end
```

Then build firmware the way you'd build for any other target:

```bash
export MIX_TARGET=my_board
mix deps.get
mix firmware
```

For more details on building custom systems and creating distributable artifacts, see the [Customizing Your Nerves System](https://hexdocs.pm/nerves/customizing-systems.html) guide.

#### Iterating on the system config

When you're tweaking your system, you'll want to use `mix nerves.system.shell` to get into the Buildroot configuration environment. From there you can run `make menuconfig`, `make linux-menuconfig`, and `make savedefconfig` to iterate on the configuration without rebuilding from scratch every time. See the [Buildroot Package Configuration](https://hexdocs.pm/nerves/customizing-systems.html#buildroot-package-configuration) section for the full workflow.

## Where to go from here

Once your system builds and you can flash a firmware image, you're in familiar Nerves territory. The next steps are usually:

- **Get network access** - set up [VintageNet](https://hexdocs.pm/vintage_net/) for Ethernet or WiFi
- **Enable SSH** - add [NervesSSH](https://hexdocs.pm/nerves_ssh/) to your application
- **Test OTA updates** - make sure `mix upload` works over the network
- **Publish your system** - create [artifacts](https://hexdocs.pm/nerves/customizing-systems.html#creating-an-artifact) so others can use your system without compiling it from source

And if you get stuck, the [Nerves Discord](https://discord.gg/7TqSpepHw7) and [Nerves Forum](https://elixirforum.com/c/elixir-framework-forums/nerves-forum/74) are full of people who have been through this process and are happy to help.
