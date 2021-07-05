# Getting Started

## Introduction

Nerves defines a new way to build embedded systems using Elixir.  It is
specifically designed for embedded systems, not desktop or server systems.  You
can think of Nerves as containing three parts:

**Platform** - a customized, minimal Buildroot-derived Linux that boots directly to the BEAM VM.

**Framework** - ready-to-go library of Elixir modules to get you up and running quickly.

**Tooling** - powerful command-line tools to manage builds, update firmware, configure devices, and more.

Taken together, the Nerves platform, framework, and tooling provide a highly specialized environment for using Elixir to build advanced embedded devices.

## Common terms

In the following guides, support channels, and forums, you may hear the following terms being used.

Term | Definition
--- | ---
host | The computer on which you are editing source code, compiling, and assembling firmware
target | The platform for which your firmware is built (for example, Raspberry Pi, Raspberry Pi 2, or Beaglebone Black)
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

> NOTE: If you've used Nerves in the past, you may have noticed that you no
> longer need to specify a `--target` option when creating a new project.  Since
> Nerves Bootstrap 0.3.0, the default target is `host` unless you specify a
> different target in your environment.  This allows for more seamless
> interaction with tools on your host without cross-compilers getting in the way
> until you're ready to build firmware for a particular target.

``` bash
mix nerves.new hello_nerves
```

Nerves will generate the required files and directory structure for your
application. If you chose not to fetch dependencies during project generation, you will need
to do that yourself.

As described by the project generator, the next step is to change to the project
directory, choose a target, and fetch the target-specific dependencies.  Visit
the [Targets Page](targets.html) for more information on what target name to use
for each of the boards that Nerves supports.

The target is chosen using a shell environment variable, so if you use the
`export` command, it will remain in effect as long as you leave that window
open.  Alternatively, you can prefix each command with the environment variable.
We find that it's easiest to have two shell windows open: one remaining
defaulted to the `host` target and one with the desired `MIX_TARGET` variable
set.  This allows you quick access to use host-based tooling in the former and
deploy updated firmware from the latter, all without having to modify the
`MIX_TARGET` variable in your shell.

``` bash
cd hello_nerves
export MIX_TARGET=rpi3
mix deps.get
```

**OR**

```bash
cd hello_nerves
MIX_TARGET=rpi3 mix deps.get
```

## Building and deploying firmware

Once the dependencies are fetched, you can build a Nerves Firmware (a bundle
that contains a minimal Linux platform and your application, packaged as an OTP
release).  The first time you ask any dependencies or your application to
compile, Nerves will fetch the System and Toolchain from one of our cache
mirrors.  These artifacts are cached locally in `~/.nerves/artifacts` so they
can be shared across projects.

For remote deployment information, see "How do I push firmware updates
remotely?" in the [FAQ](FAQ.md#how-do-i-push-firmware-updates-remotely).

### Create the firmware bundle

You can create the firmware bundle with the following command:

```bash
mix firmware # -OR- # MIX_TARGET=rpi3 mix firmware
```

This will result in a `hello_nerves.fw` firmware bundle file.
To create a bootable SD card, use the following command:

```bash
mix firmware.burn # -OR- # MIX_TARGET=rpi3 mix firmware.burn
```

This command will attempt to automatically discover the SD card inserted in your
host.  This may fail to correctly detect your SD card, for example, if you have
more than one SD card inserted or you have disk images mounted.  If this
happens, you can specify the intended device by passing the `-d <device>`
argument to the command.

```bash
# For example:
mix firmware.burn -d /dev/rdisk3
```

> NOTE: You can also use `-d <filename>` to specify an output file that is a raw image of the SD card.
This binary image can be burned to an SD card using `fwup`, `dd`, `Win32DiskImager`, or some other image copying utility.

The `mix firmware.burn` task uses the `fwup` tool internally; any extra
arguments passed to it will be forwarded along to `fwup`.  For example, if you
are sure there is only one SD card inserted, you can also add the `-y` flag to
skip the confirmation that it is the correct device.

```bash
mix firmware.burn -y # -OR- # MIX_TARGET=rpi3 mix firmware.burn -y
```

You can read about the other supported options in the [`fwup` documentation](https://github.com/fwup-home/fwup#invoking).

Now that you have your SD card burned, you can insert it into your device and
boot it up.  For Raspberry Pi, be sure to connect it to an HDMI display and USB
keyboard so you can see it boot to the IEx console.

## Connecting to your Nerves target

You can connect to an RPi0, RPi3A, and BBB with just a USB cable. These Nerves
targets can operate in Linux USB gadget mode, which means a network connection
can be made with a USB cable between your host and target. The USB cable
provides both power and network connectivity. This is a very convenient way to
work with your target device.

The RPi3B/B+ does not have USB gadget mode capability, but you can make a
network connection using either wired or wireless Ethernet.

### Attach a USB cable to the RPi0 / RPi0W / RPi0WH

Connect a USB cable between your host and the RPi0 USB port closest to the
middle of the board that is labeled "USB". This USB port, via the USB cable,
will provide both power to the board and a virtual Ethernet network
connection.

If you don't see any activity lights blinking on the board after plugging in
your USB cable, something's not working right. So then, rather power up your
RPi0 using a dedicated power supply, and use your USB cable only for
communication.

#### Test the connection

Once the target is powered up, test the connection from your host:

```bash
ping nerves.local
```

> Note: If this does not work it may be because your USB cable only has power
> lines. You need a cable with both power and data lines, so try a different USB
> cable.
>
> Note: If Windows `Device Manager`/`Network adapters` does not have a
> `USB Ethernet/RNDIS Gadget` device, it might be caused by
> [this](https://www.ghacks.net/2020/09/28/should-you-install-windows-10s-optional-driver-updates),
> so install the optional `USB Ethernet/RNDIS Gadget` driver to fix it.
>
> Note: `nerves.local` is an mDNS address. These examples were done with a Mac
> host, which has mDNS enabled by default. Linux and Windows hosts may have to
> enable mDNS networking.

#### Make the network connection

To make a connection via the USB gadget mode virtual Ethernet interface:

```bash
ssh nerves.local
```

You should find yourself at the `iex(hello_nerves@nerves.local)1>` prompt. Enter the following command:

```elixir
h Toolshed
```

This displays the help for the
[Toolshed](https://hexdocs.pm/toolshed/Toolshed.html) package, which contains
many useful commands. Go ahead and try them out to explore your target's runtime
environment.

To end your ssh connection type `exit`, or you can use the `ssh` command
`<enter>~.`

### Wireless and wired Ethernet connections
The `config/config.exs` generated in a new Nerves project will setup connections
for USB and Ethernet by default. Instructions on further configuring them, or to
configure wireless connections, please refer to [Configure networking](https://hexdocs.pm/nerves/user-interfaces.html#configure-networking) or [VintageNet](https://hexdocs.pm/vintage_net)
documentation.

### Alternate connection methods

There are a couple alternate connection methods:

#### Gadget-mode virtual serial connection

USB gadget mode also supplies a virtual serial connection. Use it with any
terminal emulator like `screen` or `picocom`:

```bash
screen /dev/usb* 115200     # replace "usb*" with the name of your host's USB port
```

You should be at an `iex(1)>` prompt. If not, try pressing `Enter` a few times.

#### USB to TTL serial cable

In addition to the wired and wireless connection method described above, targets
without USB gadget mode can be accessed via a serial connection with a TTL
cable. The TTL cable is connected between the host USB port and a couple of
header pins on the target. We've had good luck with [this
cable](https://www.adafruit.com/product/954) and the site also contains a
[tutorial](https://learn.adafruit.com/adafruits-raspberry-pi-lesson-5-using-a-console-cable/overview)
on how to use it.

You will also need to modify your Nerves configuration as described in the
[Using a USB Serial Console](https://hexdocs.pm/nerves/faq.html#using-a-usb-serial-console) FAQ
topic.

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
export MIX_TARGET=rpi3
cd nerves_examples/blinky
mix do deps.get, firmware, firmware.burn
```
