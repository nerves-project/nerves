<!--
  SPDX-FileCopyrightText: 2016 Justin Schneck
  SPDX-FileCopyrightText: 2017 Greg Mefford
  SPDX-FileCopyrightText: 2018 Frank Hunleth
  SPDX-FileCopyrightText: 2019 Dean Chouinard
  SPDX-FileCopyrightText: 2022 Masatoshi Nishiguchi
  SPDX-FileCopyrightText: 2023 Andrew Henkel
  SPDX-FileCopyrightText: 2023 Josh Kalderimis
  SPDX-FileCopyrightText: 2025 Marc Lainez
  SPDX-License-Identifier: CC-BY-4.0
-->
# Getting Started

## Introduction

Nerves provides tooling and libraries for building software images to run on embedded systems.
It uses the rock-solid [Erlang virtual machine](https://www.erlang.org/),
and brings the happy development experience of Elixir to your micro computers.

While the Nerves project provides base runtime libraries for hardware access and
network configuration, nearly all of the Elixir ecosystem is available.

Nerves uses the Linux kernel to support a large variety of hardware. It is not a
Linux distribution, though, and contains little of what you would find on a
typical embedded Linux system. Instead, it starts the Erlang runtime as one of
the first OS processes and lets Erlang and Elixir take over from there. Not to
fear, if you need something from Linux, Nerves provides a way to use most of the
packages available through [Buildroot](https://buildroot.org).

## Nerves Burner

Looking for the fastest way to get started with discovering Nerves? Then we strongly recommend to check out [Nerves Burner](https://github.com/nerves-project/nerves_burner).

This tool removes the friction of burning your first MicroSD card. Nerves Burner supports:
- [Nerves Livebook](#nerves-livebook) to run Livebook on your device and play with Elixir in no time
- [Circuits Quickstart](hardware-interfaces.html#elixir-circuits) to learn about controlling leds, and other hardware components with Elixir
- Setting up Wifi so you can easily connect to your device

This is what [Nerves Burner](https://github.com/nerves-project/nerves_burner) looks like:

![Nerves burner demo](https://raw.githubusercontent.com/nerves-project/nerves_burner/refs/heads/main/demo.gif)

## Nerves + Livebook

A great path to exploring Nerves for the first time is by setting up the
[Nerves Livebook project](https://github.com/nerves-livebook/nerves_livebook).
This allows you to try out the Nerves project on real hardware without needing
to build a project from scratch.

Within minutes, you'll have a Raspberry Pi or Beaglebone running Livebook on top of Nerves.
You'll be able to run code in [Livebook](https://livebook.dev/) and work through
Nerves tutorials from the comfort of your browser.

[Underjord](https://www.youtube.com/c/Underjord) has put together a
[fantastic video](https://www.youtube.com/watch?v=-b5TPb_MwQE)
to help walk-through the entire setup process.

If you'd rather build your own firmware from scratch, make yourself at ease, you're in the right place.

## Development environment

Before you start using Nerves, it is important that you follow the instructions from
the [Installation Guide](installation.html). It will help you get your machine
configured for running Nerves. Come back here when you're done!

## Creating a project

Let's get you set up and through your first `Hello World` moment. If you already have some experience with Nerves, you should skip this section and go straight to the core documentation.

We will start by creating a new Nerves project. The `nerves.new` project generator can be called
from anywhere and can take either an absolute path or a relative path.

``` bash
mix nerves.new hello_nerves
```

Nerves will generate the required files and directory structure for your application. We'll give more details about them in the [Anatomy of a Nerves project](#anatomy-of-a-nerves-project) section.

As described by the project generator, the next step is to change to the project
directory, choose a target, and fetch the target-specific dependencies.

What is a target? It is the platform for which your firmware is built (for example, a Raspberry Pi Zero 2W). The firmware is a binary image containing both the Linux operating system we need, as well as your Nerves project. This is what we will build with Nerves and then flash on the target. For the rest of this section, we will assume that you are working with a Raspberry Pi board, but the instructions apply to other targets as well. If you ever get confused about the terms we use in this guide, we've consolidated a list of [common terms](#common-terms) for you.

In the introduction, we mentioned that Nerves uses Linux as its foundation. But we don't use a pre-existing Linux distribution, instead, we use a `build system` to compile only what we need, that is what [Buildroot](https://buildroot.org) is for. It allows us to use just the right amount of Linux software we need to keep our images as small as possible. Don't worry, you don't need to understand how Buildroot works at this point, but in order to be able to continue, you need to know which `Nerves System` you will need for your target.

The `Nerves System` is a pre-compiled Linux Operating System, built with Buildroot, on which you will run your application. But to avoid having to compile our Nerves system each time we build a firmware, we leverage  `pre-compiled Nerves systems`. Assuming you are using Nerves for the first time on a Raspberry Pi, this is the list of Nerves systems for each Pi version (Target):

Target | System | Tag
------ | ------ | ---
Raspberry Pi A+, B, B+ | [nerves_system_rpi](https://github.com/nerves-project/nerves_system_rpi) | `rpi`
Raspberry Pi Zero and Zero W | [nerves_system_rpi0](https://github.com/nerves-project/nerves_system_rpi0) | `rpi0`
Raspberry Pi 2 | [nerves_system_rpi2](https://github.com/nerves-project/nerves_system_rpi2) | `rpi2`
Raspberry Pi 3A and Zero 2 W (32 bits) | [nerves_system_rpi3a](https://github.com/nerves-project/nerves_system_rpi3a) | `rpi3a`
Raspberry Pi 3A and Zero 2 W (64 bits) | [nerves_system_rpi0_2](https://github.com/nerves-project/nerves_system_rpi0_2) | `rpi0_2`
Raspberry Pi 3 B, B+ | [nerves_system_rpi3](https://github.com/nerves-project/nerves_system_rpi3) | `rpi3`
Raspberry Pi 4 | [nerves_system_rpi4](https://github.com/nerves-project/nerves_system_rpi4) | `rpi4`
Raspberry Pi 5 | [nerves_system_rpi5](https://github.com/nerves-project/nerves_system_rpi5) | `rpi5`

> #### One Nerves System can support multiple Pis {: .info}
> Note that some Pi versions or variations share the same system! For instance, you'll need to use `nerves_system_rpi3a` for a Raspberry Pi Zero 2W running at 32 bits and `nerves_system_rpi0_2` for a Raspberry Pi Zero 2W 64 bits, so look carefully to make sure you pick the right system.

> #### What is my device's _MIX_TARGET_? {: .tip}
>
> Visit the [Supported Targets Page](supported-targets.html) for information on what target name to
> use for each of the boards that Nerves supports. The default target is `host`
> unless you specify a different target in your environment. If you are not using a Raspberry Pi to follow this guide, you should go take a look and identify the system you need. What is relevant at this point is what's in the `tag` column.

Since the Raspberry Pi Zero 2W is the cheapest device you can find that supports Nerves, we will assume that's the target you are using for the rest of this guide. We will use the 64 bits flavour of the system, hence using the tag `rpi0_2` throughout this guide.

The target is chosen using a shell environment variable called `MIX_TARGET`. Do not forget to replace the `rpi0_2` in the examples below with the right `tag` for your target.

> #### MIX_TARGET Pro tip {: .tip}
>
> It is not mandatory, but you can set the `MIX_TARGET` environment variable once and for all in your current shell using:
>
> `export MIX_TARGET=rpi0_2`
>
> You will have to do this again if you close your terminal or if you open a new one though.
>
> An often used approach is to have two shell windows open: one for running
> commands against your local machine (the `host` target), and one with the desired `MIX_TARGET`
> variable set.
>
> This allows you quick access to use host-based tooling in the former and
> deploy updated firmware from the latter, all without having to modify the
> `MIX_TARGET` variable in your shell.

Let's get all the dependencies that our system needs.

```bash
cd hello_nerves
MIX_TARGET=rpi0_2 mix deps.get
```

You should now have installed all the dependencies required! If you encounter any issues at this point, make sure you've followed the [Installation Guide](installation.html) properly. It's time to build our first firmware with:

```bash
MIX_TARGET=rpi0_2 mix firmware
```

After a couple minutes at most, you should see the following message:

```plain
Firmware built successfully! 🎉

Now you may install it to a MicroSD card using `mix burn` or upload it
to a device with `mix upload` or `mix firmware.gen.script`+`./upload.sh`.
```

It's time to burn our firmware and try it out on our Raspberry Pi! 🔥

Insert your MicroSD card in your computer and run the following command:

```bash
MIX_TARGET=rpi0_2 mix firmware.burn
```

> #### Warning - This will wipe any existing data on your card {: .warning}
>
> Nerves will replace any existing partition or data on your MicroSD card. Make sure you save any important data you have on it before burning it with your Nerves firmware.
> You do not need to partition the card before you use it, Nerves takes care of everything for you.
>
> Most MicroSD cards should be suitable, but in case you have issues with your Raspberry Pi booting with it, check if there is not a compatibility issue by reading the [SD Cards](https://www.raspberrypi.com/documentation/computers/getting-started.html#recommended-sd-cards) section of the official documentation and search online for best brands and models for your board.

Nerves should automatically discover the right drive to flash the image and ask you to confirm. If you have more than one device available, Nerves might get confused and fail here. In that case, check the [Create a bootable SD card](#create-a-bootable-sd-card) section for more guidance. But here is an example of what you should see:

```plain
==> hello_nerves

Nerves environment
  MIX_TARGET:   rpi0_2
  MIX_ENV:      dev

Use XX.X GiB memory card found at /dev/sdX? [Yn]
```

Press `Y` or the `Enter` key and after a few seconds or minutes, your card will be burnt with your brand new nerves firmware. You can now insert your MicroSD card in your Raspberry Pi!

Before you boot it, we need to choose a way to connect with it once Nerves is launched. We will describe the easiest method (Ethernet over USB) in this guide, but there is more on the [Connecting to your Nerves Target](connecting-to-a-nerves-target.html) page if you want to take a look at it.

## Connecting to Nerves via USB

By default, on most systems, Nerves provides an [ethernet over USB interface](https://en.wikipedia.org/wiki/Ethernet_over_USB) interface. It means that you just need to plug your Pi to your computer with the appropriate USB cable to be able to interact with it. Once it is booted, you will see a new network interface created on your own computer with an IP assigned. If you run into some issues trying to connect with USB, check the [USB Data Cable](#usb-data-cable) section to help you as it might be related to the cable you are using.

Once it is booted, you can access your Raspberry Pi with the following command:

```bash
ssh nerves.local
```

Be patient though, as it can take 30 seconds or more at first boot. You can run `ping nerves.local` to know when your Pi is up and running.

The way Nerves does this is by copying your ssh public keys in the firmware and setting all up with [Vintage Net Direct](https://github.com/nerves-networking/vintage_net_direct), one of the supported [Vintage Net](https://github.com/nerves-networking/vintage_net) configurations.

> #### SSH public keys {: .info}
> Since Nerves copies your SSH public keys in the firmware image, make sure you use the same computer to create the firmware and to connect to the device. Otherwise, you will be met with a login prompt.

> #### I can't reach nerves.local {: .warning}
> If for some reason you can't reach `nerves.local`, check your operating system's network settings. You should see a network interface with an IP address starting with `172.31.`. Check the details of that interface and in the `DHCP` settings, check for the `gateway` IP address, this is your target's IP and you can `ssh` to that IP instead of `nerves.local`.

If you are using an HDMI capable Pi and USB is really not working for you, try to connect it to a screen or a TV and see if it displays the [IEx prompt](#using-iex).

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
hello_nerves 0.2.0 (40705268-3e85-52b6-7c7a-05ffd33a31b8) arm rpi0_2
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

In the IEx prompt type `HelloNerves.hello()`, and you should see your first Elixir application output! 🥳

```elixir
iex> HelloNerves.hello()
:world
```

The [Toolshed](https://hexdocs.pm/toolshed/Toolshed.html) package contains
many useful commands. Enter the following command to display the help for the
[Toolshed](https://hexdocs.pm/toolshed/Toolshed.html) package.

```elixir
iex> h Toolshed
```

Go ahead and try them out to explore your target's runtime environment.

For more info on Nerves-specific use of the IEx prompt, refer to
[IEx with Nerves Page](https://hexdocs.pm/nerves/iex-with-nerves.html).

## Anatomy of a Nerves project

Now that we have managed to boot our Pi with our own firmware, let's see what a Nerves project actually looks like:

```plain
hello_nerves
├── config
├── lib
├── mix.exs
├── README.md
├── test
└── rootfs-overlay
    └── etc
        └── iex.exs
```

The `mix.exs` is where we make the link between our firmware and the Nerves System that is needed for our target.

```elixir
defmodule HelloNerves.MixProject do
  use Mix.Project

  @app :hello_nerves
  @version "0.1.0"
  @all_targets [
    :rpi,
    :rpi0,
    :rpi0_2,
    :rpi2,
    :rpi3,
    :rpi3a,
    :rpi4,
    :rpi5,
    :bbb,
    :osd32mp1,
    :x86_64,
    :grisp2,
    :mangopi_mq_pro
  ]

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.17",
      archives: [nerves_bootstrap: "~> 1.14"],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [{@app, release()}],
      preferred_cli_target: [run: :host, test: :host]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :runtime_tools],
      mod: {HelloNerves.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Dependencies for all targets
      {:nerves, "~> 1.10", runtime: false},
      {:shoehorn, "~> 0.9.1"},
      {:ring_logger, "~> 0.11.0"},
      {:toolshed, "~> 0.4.0"},

      # Allow Nerves.Runtime on host to support development, testing and CI.
      # See config/host.exs for usage.
      {:nerves_runtime, "~> 0.13.0"},

      # Dependencies for all targets except :host
      {:nerves_pack, "~> 0.7.1", targets: @all_targets},

      # ...
      {:nerves_system_rpi, "~> 1.24", runtime: false, targets: :rpi},
      {:nerves_system_rpi0, "~> 1.24", runtime: false, targets: :rpi0},
      {:nerves_system_rpi0_2, "~> 1.24", runtime: false, targets: :rpi0_2},
      {:nerves_system_rpi2, "~> 1.24", runtime: false, targets: :rpi2},
      {:nerves_system_rpi3, "~> 1.24", runtime: false, targets: :rpi3},
      {:nerves_system_rpi3a, "~> 1.24", runtime: false, targets: :rpi3a},
      {:nerves_system_rpi4, "~> 1.24", runtime: false, targets: :rpi4},
      {:nerves_system_rpi5, "~> 0.2", runtime: false, targets: :rpi5},
      {:nerves_system_bbb, "~> 2.19", runtime: false, targets: :bbb},
      {:nerves_system_osd32mp1, "~> 0.15", runtime: false, targets: :osd32mp1},
      {:nerves_system_x86_64, "~> 1.24", runtime: false, targets: :x86_64},
      {:nerves_system_grisp2, "~> 0.8", runtime: false, targets: :grisp2},
      {:nerves_system_mangopi_mq_pro, "~> 0.6", runtime: false, targets: :mangopi_mq_pro}
    ]
  end

  def release do
    [
      overwrite: true,
      #...
      cookie: "#{@app}_cookie",
      include_erts: &Nerves.Release.erts/0,
      steps: [&Nerves.Release.init/1, :assemble],
      strip_beams: Mix.env() == :prod or [keep: ["Docs"]]
    ]
  end
end

```

As you can see in the `@all_targets` global variable and in the `deps` function, we list all the official Nerves Systems, but only the one selected with `MIX_TARGET` as explained above will be used when you build your firmware.

Just like any Elixir project, `deps` is where you can add additional dependencies that you need.

The `application` function is where you describe your whole application. The `:mod` key let's you define the module that will be invoked when the application is started. At this point in your Nerves journey, this is the only part that matters, but you're welcome to read more about the `application` function by running `mix help compile.app` in your terminal.

The module named `HelloNerves.Application` is located in the project's `lib/hello_nerves` directory.

If you have any experience with Elixir, this should feel like home. A Nerves Application is just a good old [Elixir OTP application](https://hexdocs.pm/elixir/Application.html) where we implement the `Application` behaviour. The `start/2` callback starts a supervison tree, just like any other [Elixir OTP application](https://hexdocs.pm/elixir/Application.html).

## Updating your firmware

Working on a Nerves project, you'll find yourself making changes to your application and wanting to try these changes on your target. However, we don't want to always remove the MicroSD card from the target, which means we will update the firmware over the network. Make sure you can [connect to your device with USB](#connecting-to-nerves-via-usb) before following this section.

Something easy we can change is the `hello` function in our `HelloNerves` module located in `lib/hello_nerves.ex`:

```elixir
defmodule HelloNerves do
  # ...
  def hello do
    :world
  end
end
```

Let's just change `:world` to `:nerves` 😉

```elixir
  def hello do
    :nerves
  end
```

Save the file and rebuild the firmware with:

```bash
MIX_TARGET=rpi0_2 mix firmware
```

Since we already have Nerves running on the target which is connected with a USB cable, we can upload our new firmware over the network. We don't need to run `firmware.burn` anymore.

```bash
MIX_TARGET=rpi0_2 mix upload
```

It will push your new version of the firmware and reboot the target. Once it is accessible again, run `ssh nerves.local`. When you get to the IEx prompt, you should see the following when calling the `hello` function:

```elixir
iex> HelloNerves.hello()
:nerves
```

Congratulations! 🎊 You've just reached your very own Nerves `Hello world` moment and have assimilated all the basic concepts you need to go further. Whether you want to [Run a phoenix app](./user-interfaces.html#phoenix-web-interface), play around with your Pi's [GPIO](./hardware-interfaces.html#elixir-circuits), the world is now your oyster. If at any point in your journey you feel stuck, reach out to the Nerves community through [our communication channels](#community-links). Welcome to Nerves!



## Example projects

If you are interested in exploring other Nerves codebases and projects, you can
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
export MIX_TARGET=rpi0_2
cd nerves_examples/blinky
mix do deps.get, firmware, firmware.burn
```

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

## Community links

Do not hesitate to seek for help if you feel stuck at any point during your journey with Nerves.

- [Nerves Discord](https://discord.gg/7TqSpepHw7)
- [Nerves Forum](https://elixirforum.com/c/elixir-framework-forums/nerves-forum/74)
- [Nerves Meetup](https://www.meetup.com/nerves)
- [Nerves Newsletter](https://underjord.io/nerves-newsletter.html)

## Deploying your firmware

Moved to [Using Nerves](./using-nerves.html#deploying-your-firmware)

### Create the firmware bundle

Moved to [Using Nerves](./using-nerves.html#create-the-firmware-bundle)

### Create a bootable SD card

Moved to [Using Nerves](./using-nerves.html#create-a-bootable-sd-card)

## Connecting to your device

Moved to [Using Nerves](./using-nerves.html#connecting-to-your-device)
