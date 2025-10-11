# Getting Started

## Introduction

Nerves provides tooling and libraries for building software images to run on embedded systems.
It uses the the rock-solid [Erlang virtual machine](https://www.erlang.org/), 
and brings the happy development experience of Elixir to your micro computers. 

While the Nerves project provides base runtime libraries for hardware access and
network configuration, nearly all of the Elixir ecosystem is available.

Nerves uses the Linux kernel to support a large variety of hardware. It is not a
Linux distribution, though, and contains little of what you would find on a
typical embedded Linux system. Instead, it starts the Erlang runtime as one of
the first OS processes and lets Erlang and Elixir take over from there. Not to
fear, if you need something from Linux, Nerves provides a way to use most of the
packages available through [Buildroot](https://buildroot.org).

## Common terms

In the following guides, support channels, and forums, you may hear the
following terms being used.

| Term            | Definition |
| --------------- | ---------- |
| host            | The computer on which you are editing source code, compiling, and assembling firmware |
| target          | The platform for which your firmware is built (for example, Raspberry Pi Zero W, Raspberry Pi 4, or Beaglebone Black) |
| toolchain       | The tools required to build code for the target, such as compilers, linkers, binutils, and C runtime |
| system          | A lean Buildroot-based Linux distribution that has been customized and cross-compiled for a particular target |
| firmware bundle | A single file that contains an assembled version of everything needed to burn firmware |
| firmware image  | Built from a firmware bundle and contains the partition table, partitions, bootloader, etc. |

## Development environment

Before you create your first Nerves project or explore Nerves with Livebook,
you will need to make sure to [install some system
packages](installation.html) required by the Framework, Platform,
and Tooling.

## Nerves + Livebook

A great path to exploring Nerves for the first time is by setting up the
[Nerves Livebook project](https://github.com/nerves-livebook/nerves_livebook).
This allows you to try out the Nerves project on real hardware without needing
to build a project from scratch.

Within minutes, you'll have a Raspberry Pi or Beaglebone running Nerves. You'll
be able to run code in [Livebook](https://livebook.dev/) and work through
Nerves tutorials from the comfort of your browser.

[Underjord](https://www.youtube.com/c/Underjord) has put together a
[fantastic video](https://www.youtube.com/watch?v=-b5TPb_MwQE)
to help walk-through the entire setup process.

If you'd rather build your own firmware from scratch, make yourself at ease, you're in the right place.

## Creating a project

Before you start using Nerves, it is important that you take a minute to read
the [Installation Guide](installation.html).  It will help you get your machine
configured for running Nerves.

Let's create a new project.  The `nerves.new` project generator can be called
from anywhere and can take either an absolute path or a relative path.

``` bash
mix nerves.new hello_nerves
```

Nerves will generate the required files and directory structure for your
application. If you chose not to fetch dependencies during project generation,
you will need to do that yourself.

As described by the project generator, the next step is to change to the project
directory, choose a target, and fetch the target-specific dependencies.

> #### What is my device's _MIX_TARGET_? {: .tip}
>
> Visit the [Supported Targets Page](supported-targets.html) for information on what target name to
> use for each of the boards that Nerves supports. The default target is `host`
> unless you specify a different target in your environment.

The target is chosen using a shell environment variable. You can use the
`export` command, which will remain in effect as long as you leave your
shell window open.

``` bash
cd hello_nerves
export MIX_TARGET=rpi0
mix deps.get
```

Alternatively, you can prefix each command with the environment variable.

``` bash
cd hello_nerves
MIX_TARGET=rpi0 mix deps.get
```

An often used approach is to have two shell windows open: one for running
commands against the `host` target, and one with the desired `MIX_TARGET`
variable set.

This allows you quick access to use host-based tooling in the former and
deploy updated firmware from the latter, all without having to modify the
`MIX_TARGET` variable in your shell.

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
MIX_TARGET=rpi0 mix firmware
```

This will result in a `hello_nerves.fw` firmware bundle file.

### Create a bootable SD card

To create a bootable SD card, use the following command:

```bash
mix firmware.burn
```

or

```bash
MIX_TARGET=rpi0 mix firmware.burn
```

This command will attempt to automatically discover the SD card inserted in your
host.

> #### More than one SD cards or disk images? {: .tip}
>
> `mix firmware.burn` may fail to correctly detect your SD card if you have
> more than one SD card inserted or you have disk images mounted.
>
> If this happens, you can specify the intended device by passing the
> `-d <device>` argument to the command. For example
> `mix firmware.burn -d /dev/rdisk3`
>
> You can alse use `-d <filename>` to specify an output file that is a raw
> image of the SD card. This binary image can be burned to an SD card using
> [Raspberry Pi Imager](https://www.raspberrypi.com/software/), [Etcher](https://www.balena.io/etcher/), `dd`, `Win32DiskImager`, or other image copying utilities.

For more options, refer to the `mix firmware.burn` documentation.

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
> supported features. As an example, when your target is `rpi0`,
> visit https://hexdocs.pm/nerves_system_rpi0.

## Using `IEx`

Once you are connected to your target device, an `IEx` prompt will appear with
[`NervesMOTD`](https://hexdocs.pm/nerves_motd/readme.html).
`IEx` is your main entry point to interacting with Elixir, your program, and hardware.

```bash
ssh nerves.local

Interactive Elixir (1.18.3) - press Ctrl+C to exit (type h() ENTER for help)
████▄▄    ▐███
█▌  ▀▀██▄▄  ▐█
█▌  ▄▄  ▀▀  ▐█   N  E  R  V  E  S
█▌  ▀▀██▄▄  ▐█
███▌    ▀▀████
hello_nerves 0.2.0 (40705268-3e85-52b6-7c7a-05ffd33a31b8) arm rpi0
  Uptime       : 1 days, 3 hours, 6 minutes and 29 seconds
  Clock        : 2022-08-11 21:44:09 EDT

  Firmware     : Valid (B)               Applications : 57 started
  Memory usage : 87 MB (28%)             Part usage   : 2 MB (0%)
  Hostname     : nerves-mn02             Load average : 0.15 0.12 0.14

  wlan0        : 10.0.0.25/24, 2601:14d:8602:2a0:ba27:ebff:fecb:222a/64, fe80::ba27:ebff:fecb:222a/64
  usb0         : 172.31.36.97/30, fe80::3c43:59ff:fec9:6716/64

Nerves CLI help: https://hexdocs.pm/nerves/iex-with-nerves.html

Toolshed imported. Run h(Toolshed) for more info.
iex(nerves@nerves.local)1>
```

The [Toolshed](https://hexdocs.pm/toolshed/Toolshed.html) package contains
many useful commands. Enter the following command to display the help for the
[Toolshed](https://hexdocs.pm/toolshed/Toolshed.html) package.

```elixir
h Toolshed
```

Go ahead and try them out to explore your target's runtime environment.

For more info on Nerves-specific use of the IEx prompt, refer to
[IEx with Nerves Page](https://hexdocs.pm/nerves/iex-with-nerves.html).

## Example projects

If you are interested in exploring other Nerve codebases and projects, you can
check out our [collection of example projects](https://github.com/nerves-project/nerves_examples).

Be sure to set your `MIX_TARGET` environment variable appropriately for the
target hardware you have. Visit the [Supported Targets Page](supported-targets.html) for more
information on what target name to use for the boards that Nerves supports.

The `nerves_examples` repository contains several example projects to get you
started.  The simplest example is Blinky, known as the "Hello World" of hardware
because all it does is blink an LED indefinitely.  If you are ever curious about
project structuring or can't get something running, check out Blinky and run it
on your target to confirm that it works in the simplest case.

```bash
git clone https://github.com/nerves-project/nerves_examples
export MIX_TARGET=rpi0
cd nerves_examples/blinky
mix do deps.get, firmware, firmware.burn
```

## Community links

- [Elixir Discord #nerves channel](https://discord.gg/elixir)
- [Nerves Forum](https://elixirforum.com/c/elixir-framework-forums/nerves-forum/74)
- [Nerves Meetup](https://www.meetup.com/nerves)
- [Nerves Newsletter](https://underjord.io/nerves-newsletter.html)
