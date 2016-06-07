# Getting Started

## Introduction

Nerves defines an entirely new way to build embedded systems using Elixir. It is specifically designed for embedded systems, not desktop or server systems. You can think of Nerves as containing three parts:

**Platform** - a customized, minimal buildroot-derived Linux that boots directly to the BEAM VM.

**Framework** - ready-to-go library of Elixir modules to get you up and running quickly.

**Tooling** - powerful command-line tools to manage builds, update firmware, configure devices, and more.

Taken together, the Nerves platform, framework, and tooling provide a highly specialized environment for using Elixir to build advanced embedded devices.

## Common Terms

In the following guides, support channels, and forums you may hear the following terms being used.

Term | Definition
--- | ---
host | The computer on which you are editing source code, compiling, and assembling firmware
target | The platform for which your firmware is built (for example, Raspberry Pi, Raspberry Pi 2, or Beaglebone Black)
toolchain | The tools required to build code for the target, such as compilers, linkers, binutils, and C runtime
system | A lean buildroot-based linux distribution that has been customized and cross-compiled for a particular target
application | The Elixir (and any native, e.g. C) source code for your project. Note that this may entail more than one "application" in Elixir parlance.
configuration | The settings and other target-specific files that steer the firmware building process for your particular target
assemble | The process of combining system, application, and configuration into a firmware bundle
firmware bundle | A single file that contains an assembled version of everything needed to burn firmware
firmware image | Built from a firmware bundle and contains the partition table, partitions, bootloader, etc.

## Creating a New Nerves App

Before you start using Nerves, it is important that you take a minute to read the [Installation Guide](installation.html). It will help you get your machine configured for running Nerves.

Let's create a new project. The `nerves.new` project generator can be called from anywhere and can take either an absolute path or a relative path. The new project generator requires that you specify the default target you want the project to use. This allows you to omit the `--target` option when building firmware for the default target. Visit the [Targets Page](targets.html) for more information on what target name to use for the boards that Nerves supports.

```
$ mix nerves.new hello_nerves --target rpi3
* creating hello_nerves/config/config.exs
* creating hello_nerves/lib/my_app.ex
* creating hello_nerves/test/test_helper.exs
* creating hello_nerves/test/my_app_test.exs
* creating hello_nerves/rel/vm.args
* creating hello_nerves/rel/.gitignore
* creating hello_nerves/.gitignore
* creating hello_nerves/mix.exs
* creating hello_nerves/README.md
```

Nerves will generate the required files and directory structure needed for your application. The next step is to `cd` into your `hello_nerves` directory and fetch the dependencies

```
$ cd hello_nerves
$ mix deps.get
```

> It is important to note that Nerves supports multi-target projects. This means that the same code base can support running on a variety of different target boards. Because of this, It is very important that your mix file only includes a single `nerves_system` at any time. For more information check out the [Targets Page](targets.html#target-dependencies)

Once the dependencies are fetched, you can start to compile your project. The goal is to make a Nerves Firmware (a bundle that contains a Nerves-based linux platform and your application). As a first step, you need to fetch both the System and Toolchain for your Target. This task is done for you by Mix using the `nerves_bootstrap` utility in a special stage called `precompile`. This means that the first time you ask any dependencies or your application to compile, Nerves will fetch the System and Toolchain from one of our cache mirrors. Lets start the process and get a coffee...

```
$ mix compile
Nerves Precompile Start
...
Compile Nerves toolchain
Downloading from Github Cache
Unpacking toolchain to build dir
...
Generated nerves_system_rpi3 app
[nerves_system][compile]
[nerves_system][http] Downloading system from cache
[nerves_system][http] System Downloaded
[nerves_system][http] Unpacking System
...
Nerves Env loaded
Nerves Precompile End
```

At this point, the Nerves System and Toolchain have been pulled down to your host machine and your Mix environment has been bootstrapped to use them when you build a firmware. You can verify that Nerves is ready with the correct System and Toolchain by getting it to print out the locations of these new assets.

```
$ NERVES_DEBUG=1 mix compile
Nerves Env loaded
------------------
Nerves Environment
------------------
target:     rpi3
toolchain:  _build/rpi3/dev/nerves/toolchain
system:     _build/rpi3/dev/nerves/system
app:        /Users/nerves/hello_nerves
```

You'll notice that subsequent calls to `compile` will not fetch or build the system because they're alredy cached on you host computer.

## Making Firmware

Now that you have a compiled Nerves application, you can produce firmware. Nerves firmware is the product of turning your application into an OTP release, adding it to the system image, and laying out a partition scheme. You can create the firmware bundle with the following command:

```
$ mix firmware
Nerves Env loaded
Nerves Firmware Assembler
...
Building _images/rpi3/hello_nerves.fw...
```

This will eventually output a firmware bundle file `_images/rpi3/hello_nerves.fw`. This file is an archive-formatted bundle and metadata about your firmware release. To create a bootable SD card, you can use the following command:

```
$ mix firmware.burn
Burn rpi3-0.0.1 to SD card at /dev/rdisk3, Proceed? [Y/n]
```

This command will attempt to automatically discover the SD card inserted in your host machine. There may be situations where this command does not discover your SD card. This may occur if you have more than one SD card inserted into the machine, or you have disk images mounted at the same time. If this happens, you can specify which device to write to by passing the `-d <device>` argument to the command. This command wraps `fwup`, so any extra arguments passed to it will be forwarded along to `fwup`.

```
$ mix firmware.burn -d /dev/rdisk3
```

> Note: You can also use `-d <filename>` to specify an output file. This will allow you to create a binary image that you can burn later using `dd` or some other image copying utility.

Now that you have your SD card burned, you can insert it into your device and boot it up. For Raspberry Pi, connect it to your HDMI display and USB keyboard and you should see it boot to the IEx Console.

## Nerves Examples

To get up and running quickly, you can check out our collection of example projects:
```
$ git clone https://github.com/nerves-project/nerves-examples
$ cd nerves-examples/blinky
$ mix deps.get && mix firmware
```

The example projects contain an app called Blinky, known as "The Hello World of Hardware". If you are ever curious about project structuring or can't get something running, it is advised to check out Blinky and run it on your target.
