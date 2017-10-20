# Getting Started

## Introduction

Nerves defines an entirely new way to build embedded systems using Elixir.
It is specifically designed for embedded systems, not desktop or server systems.
You can think of Nerves as containing three parts:

**Platform** - a customized, minimal Buildroot-derived Linux that boots directly to the BEAM VM.

**Framework** - ready-to-go library of Elixir modules to get you up and running quickly.

**Tooling** - powerful command-line tools to manage builds, update firmware, configure devices, and more.

Taken together, the Nerves platform, framework, and tooling provide a highly specialized environment for using Elixir to build advanced embedded devices.

## Common Terms

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

## Creating a New Nerves App

Before you start using Nerves, it is important that you take a minute to read the [Installation Guide](installation.html).
It will help you get your machine configured for running Nerves.

Let's create a new project.
The `nerves.new` project generator can be called from anywhere and can take either an absolute path or a relative path.

> NOTE: If you've used Nerves in the past, you may have noticed that you no longer need to specify a `--target` option when creating a new project.
> Since Nerves Bootstrap 0.3.0, the default target is `host` unless you specify a different target in your environment.
> This allows for more seamless interaction with tools on your host without cross-compilers getting in the way until you're ready to build firmware for a particular target.

``` bash
mix nerves.new hello_nerves
```

Nerves will generate the required files and directory structure for your application.
After downloading the required dependencies, Nerves will generate a default release configuration file using the `mix nerves.release.init` task.
If you chose not to fetch dependencies during project generation, you will need to do that yourself.

As described by the project generator, the next step is to change to the project directory, choose a target, and fetch the target-specific dependencies.
Visit the [Targets Page](targets.html) for more information on what target name to use for each of the boards that Nerves supports.

The target is chosen using a shell environment variable, so if you use the `export` command, it will remain in effect as long as you leave that window open.
Alternatively, you can prefix each command with the environment variable.
We find that it's easiest to have two shell windows open: one remaining defaulted to the `host` target and one with the desired `MIX_TARGET` variable set.
This allows you quick access to use host-based tooling in the former and deploy updated firmware from the latter, all without having to modify the `MIX_TARGET` variable in your shell.

``` bash
cd hello_nerves
export MIX_TARGET=rpi3
mix deps.get
```

**OR**

``` bash
cd hello_nerves
MIX_TARGET=rpi3 mix deps.get
```

## Building and Deploying Firmware

Once the dependencies are fetched, you can build a Nerves Firmware (a bundle that contains a minimal Linux platform and your application, packaged as an OTP release).
The first time you ask any dependencies or your application to compile, Nerves will fetch the System and Toolchain from one of our cache mirrors.
These artifacts are cached locally in `~/.nerves/artifacts` so they can be shared across projects.

### Generating a release config file

You must generate a _release config file_ before generating a firmware bundle.
Normally, it will be created for you by the `mix nerves.new` task, but if not, you will get a warning like this:

```bash
** (Mix)   You are missing a release config file. Run  nerves.release.init task first
```

You can generate the file using this Mix task:

```bash
mix nerves.release.init
```

> NOTE: `mix nerves.release.init` generates a **Nerves-specific release config file**.
> There also exists a standard `mix release.init` generator, which is most likely not what you want.
> If you experience errors like `init terminating in do_boot (cannot expand $ERTS_LIB_DIR in bootfile)`, you most likely used the standard config generator.
> Try re-generating your release config using `mix nerves.release.init`.

### Create the firmware bundle

You can create the firmware bundle with the following command:

``` bash
mix firmware # -OR- # MIX_TARGET=rpi3 mix firmware
```

This will result in a `hello_nerves.fw` firmware bundle file.
To create a bootable SD card, use the following command:

``` bash
mix firmware.burn # -OR- # MIX_TARGET=rpi3 mix firmware.burn
```

This command will attempt to automatically discover the SD card inserted in your host.
This may fail to correctly detect your SD card, for example, if you have more than one SD card inserted or you have disk images mounted.
If this happens, you can specify the intended device by passing the `-d <device>` argument to the command.

``` bash
# For example:
mix firmware.burn -d /dev/rdisk3
```

> NOTE: You can also use `-d <filename>` to specify an output file that is a raw image of the SD card.
This binary image can be burned to an SD card using `fwup`, `dd`, `Win32DiskImager`, or some other image copying utility.

The `mix firmware.burn` task uses the `fwup` tool internally; any extra arguments passed to it will be forwarded along to `fwup`.
For example, if you are sure there is only one SD card inserted, you can also add the `-y` flag to skip the confirmation that it is the correct device.

``` bash
mix firmware.burn -y # -OR- # MIX_TARGET=rpi3 mix firmware.burn -y
```

You can read about the other supported options in the [`fwup` documentation](https://github.com/fhunleth/fwup#invoking).

Now that you have your SD card burned, you can insert it into your device and boot it up.
For Raspberry Pi, be sure to connect it to an HDMI display and USB keyboard so you can see it boot to the IEx console.

## Nerves Examples

To get up and running quickly, you can check out our [collection of example projects](https://github.com/nerves-project/nerves_examples).
Be sure to set your `MIX_TARGET` environment variable appropriately for the target hardware you have.
Visit the [Targets Page](targets.html) for more information on what target name to use for the boards that Nerves supports.

The `nerves_examples` repository contains several example projects to get you started.
The simplest example is Blinky, known as the "Hello World" of hardware because all it does is blink an LED indefinitely.
If you are ever curious about project structuring or can't get something running, check out Blinky and run it on your target to confirm that it works in the simplest case.

``` bash
git clone https://github.com/nerves-project/nerves_examples
export MIX_TARGET=rpi3
cd nerves_examples/blinky
mix do deps.get, firmware, firmware.burn
```

