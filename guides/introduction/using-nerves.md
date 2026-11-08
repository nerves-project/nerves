<!--
  SPDX-FileCopyrightText: 2025 Frank Hunleth
  SPDX-FileCopyrightText: 2025 Marc Lainez
  SPDX-License-Identifier: CC-BY-4.0
-->
# Using Nerves

## Deploying your firmware

Once you have installed your project dependencies you can build a Nerves
Firmware bundle. This bundle contains a minimal Linux platform and your
application packaged as an OTP release.

The first time you compile your application or it's dependencies Nerves will
fetch the System and Toolchain from one of our cache mirrors. These artifacts
are cached locally in `~/.nerves/artifacts` so they can be shared across
projects.

For remote deployment information, see "How do I push firmware updates
remotely?" in the [FAQ](faq.md#how-do-i-push-firmware-updates-remotely).

> #### Deleting cached artifacts {: .tip}
>
> Running `rm -fr ~/.nerves` is a safe operation as any archives
> that you're using will be re-downloaded when you next run `mix deps.get`.

### Create the firmware bundle

You can create the firmware bundle with the following command:

```bash
mix firmware
```

or

```bash
MIX_TARGET=rpi0_2 mix firmware
```

This will result in a `hello_nerves.fw` firmware bundle file.

### Create a bootable SD card

To create a bootable SD card, use the following command:

```bash
mix burn
```

or

```bash
MIX_TARGET=rpi0_2 mix burn
```

This command will attempt to automatically discover the SD card inserted in your
host.

> #### More than one SD cards or disk images? {: .tip}
>
> `mix burn` may fail to correctly detect your SD card if you have
> more than one SD card inserted or you have disk images mounted.
>
> If this happens, you can specify the intended device by passing the
> `-d <device>` argument to the command. For example
> `mix burn -d /dev/rdisk3`
>
> You can also use `-d <filename>` to specify an output file that is a raw
> image of the SD card. This binary image can be burned to an SD card using
> [Raspberry Pi Imager](https://www.raspberrypi.com/software/), [Etcher](https://www.balena.io/etcher/), `dd`, `Win32DiskImager`, or other image copying utilities.

For more options, refer to the `mix help burn`.

Now that you have your SD card burned, you can insert it into your device and
boot it up.

## Connecting to your device

There are multiple ways to connect to your Nerves target device, and different
targets may support different connection methods:

- USB to TTL serial cable (aka FTDI cable)
- HDMI cable
- USB data cable
- Ethernet
- WiFi

When connecting to your target device using a USB to TTL serial cable or an
HDMI cable, and before booting up your device, you may see device messages
related to the booting process in the IEx console.

For more info, refer to [Connecting to your Nerves Target](connecting-to-a-nerves-target.html).

> #### What features does Nerves support for my device? {: .tip}
>
> Refer to the documentation of `nerves_system_<target>` projects for their
> supported features. As an example, when your target is `rpi0_2`,
> visit https://nerves-system-rpi0-2.hexdocs.pm.

## Speeding up builds

There are a few strategies for speeding up Nerves builds:

- Enabling parallel compilation
- Caching
- Reducing work for development builds

For parallel compilation of Elixir and native code on multi-core machines, we
recommend starting with using half of your CPU cores. See
[`MIX_OS_DEPS_COMPILE_PARTITION_COUNT`](https://mix.hexdocs.pm/Mix.Tasks.Deps.Compile.html#module-compiling-dependencies-across-multiple-os-processes)
for Elixir documentation. Setting `MAKEFLAGS` has a similar effect for a lot of
native code. Be aware that some `Makefiles` don't support parallel compilation
and will need this to be unset.

To enable this, set the following in your shell configuration:

<!-- tabs-open -->
### macOS

```bash
export MIX_OS_DEPS_COMPILE_PARTITION_COUNT=$(( $(sysctl -n hw.physicalcpu) / 2 ))
export MAKEFLAGS="-j$(( $(sysctl -n hw.physicalcpu) / 2 ))"
```

### Linux

```bash
export MIX_OS_DEPS_COMPILE_PARTITION_COUNT=$(( $(nproc) / 2 ))
export MAKEFLAGS="-j$(( $(nproc) / 2 ))"
```
<!-- tabs-close -->

If you're building Nerves systems, Nerves supports
[ccache](https://ccache.dev/). This caches build products between calls to `mix
nerves.artifact.build` and can significantly speed up clean builds. Add the
following to specify a directory for the cache.

```bash
export NERVES_CCACHE_DIR="$HOME/.nerves/ccache"
```

If you have large firmware images, reducing compression settings in development
can help. For example, `fwup` defaults to its best compression setting, but can
be altered in your project's `config.exs`:

```elixir
if Mix.env() == :dev do
  # Speed up dev build time at the cost of a little .fw size
  config :nerves, :firmware, fwup_compression: :fast
end
```
