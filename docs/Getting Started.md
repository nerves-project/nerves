# Getting Started

## Introduction

Nerves defines a new way to build embedded systems using [Elixir](https://elixir-lang.org/). It is
specifically designed for embedded systems, not desktop or server systems.  You
can think of Nerves as containing three parts:

- **Platform** - a customized, minimal [Buildroot](https://buildroot.org)-derived Linux that boots directly to the [BEAM VM](https://en.wikipedia.org/wiki/BEAM_(Erlang_virtual_machine)).
- **Framework** - ready-to-go library of Elixir modules to get you up and running quickly.
- **Tooling** - powerful command-line tools to manage builds, update firmware, configure devices, and more.

Taken together, the Nerves platform, framework, and tooling provide a highly specialized environment for using Elixir to build advanced embedded devices.

## Common terms

In the following guides, support channels, and forums, you may hear the following terms being used.

Term | Definition
--- | ---
host | The computer on which you are editing source code, compiling, and assembling firmware
target | The platform for which your firmware is built (for example, Raspberry Pi Zero W, Raspberry Pi 4, or Beaglebone Black)
toolchain | The tools required to build code for the target, such as compilers, linkers, binutils, and C runtime
system | A lean Buildroot-based Linux distribution that has been customized and cross-compiled for a particular target
assemble | The process of combining system, application, and configuration into a firmware bundle
firmware bundle | A single file that contains an assembled version of everything needed to burn firmware
firmware image | Built from a firmware bundle and contains the partition table, partitions, bootloader, etc.

## Creating a new Nerves app

Before you start using Nerves, it is important that you take a minute to read
the [Installation Guide](installation.html).  It will help you get your machine
configured for running Nerves.

Let's create a new project.  The `nerves.new` project generator can be called
from anywhere and can take either an absolute path or a relative path.

``` bash
mix nerves.new hello_nerves
```

Nerves will generate the required files and directory structure for your
application. If you chose not to fetch dependencies during project generation, you will need
to do that yourself.

As described by the project generator, the next step is to change to the project
directory, choose a target, and fetch the target-specific dependencies.

> #### What is my device's _MIX_TARGET_? {: .tip}
>
> Visit the [Targets Page](targets.html) for information on what target name to
> use for each of the boards that Nerves supports. The default target is `host`
> unless you specify a different target in your environment.

The target is chosen using a shell environment variable, so if you use the
`export` command, it will remain in effect as long as you leave that window
open.

``` bash
cd hello_nerves
export MIX_TARGET=rpi0
mix deps.get
```

Alternatively, you can prefix each command with the environment variable.
We find that it's easiest to have two shell windows open: one remaining
defaulted to the `host` target and one with the desired `MIX_TARGET` variable
set.

```bash
cd hello_nerves
MIX_TARGET=rpi0 mix deps.get
```

This allows you quick access to use host-based tooling in the former and
deploy updated firmware from the latter, all without having to modify the
`MIX_TARGET` variable in your shell.

## Building and deploying firmware

Once the dependencies are fetched, you can build a Nerves Firmware (a bundle
that contains a minimal Linux platform and your application, packaged as an OTP
release).  The first time you ask any dependencies or your application to
compile, Nerves will fetch the System and Toolchain from one of our cache
mirrors.  These artifacts are cached locally in `~/.nerves/artifacts` so they
can be shared across projects.

For remote deployment information, see "How do I push firmware updates
remotely?" in the [FAQ](FAQ.md#how-do-i-push-firmware-updates-remotely).

> #### Deleting cached artifacts {: .tip}
>
> It is always OK to `rm -fr ~/.nerves`. The consequence is that the archives
> that you're using will need to be re-downloaded when you run `mix deps.get`.

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
> `mix firmware.burn` may fail to correctly detect your SD card, for example,
> if you have more than one SD card inserted or you have disk images mounted.
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

## Connecting to your Nerves target

There are multiple ways to connect to your Nerves target device and different
target may support different connection methods:

- USB to TTL serial cable (aka FTDI cable)
- HDMI cable
- USB data cable
- Ethernet
- WiFi

When connecting with a USB to TTL serial cable or an HDMI cable before booting
up your device, you can see your device booting to the IEx console.

For more info, refer to [Connecting to Nerves Target page](connecting-to-nerves-target.html).

> #### What features does Nerves support for my device? {: .tip}
>
> Refer to the documentation of `nerves_system_<target>` projects for their
> supported features. As an example, when your target is `rpi0`,
> visit https://hexdocs.pm/nerves_system_rpi0.

## Inspecting your target in `IEx`

Once you are connected to your target device, an `IEx` prompt will appear with
[`NervesMOTD`](https://hexdocs.pm/nerves_motd/readme.html).
`IEx` is your main entry point to interacting with Elixir, your program, and hardware.

```bash
ssh nerves.local

Interactive Elixir (1.13.4) - press Ctrl+C to exit (type h() ENTER for help)
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

## Nerves Livebook

The [Nerves Livebook firmware](https://github.com/livebook-dev/nerves_livebook)
lets you try out the Nerves projects on real hardware without needing to build
anything. Within minutes, you'll have a Raspberry Pi or Beaglebone running
Nerves. You'll be able to run code in [Livebook](https://livebook.dev/) and
work through Nerves tutorials from the comfort of your browser.

Looking for a quick demo first? Click below for
[Underjord](https://www.youtube.com/c/Underjord)'s Nerves Quickstart video.

[![Install video](https://github.com/livebook-dev/nerves_livebook/raw/main/assets/video.jpg)](https://www.youtube.com/watch?v=-b5TPb_MwQE)

## Nerves examples

To get up and running quickly, you can check out our [collection of example
projects](https://github.com/nerves-project/nerves_examples).  Be sure to set
your `MIX_TARGET` environment variable appropriately for the target hardware you
have.  Visit the [Targets Page](targets.html) for more information on what
target name to use for the boards that Nerves supports.

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

## Nerves communities

- [Elixir Slack #nerves channel](https://elixir-slackin.herokuapp.com/)
- [Nerves Forum](https://elixirforum.com/c/elixir-framework-forums/nerves-forum/74)
- [Nerves Meetup](https://www.meetup.com/nerves)
- [Nerves Newsletter](https://underjord.io/nerves-newsletter.html)

<p align="center">
Is something wrong?
<a href="https://github.com/nerves-project/nerves/edit/main/docs/Getting%20Started.md">
Edit this page on GitHub
</a>
</p>
