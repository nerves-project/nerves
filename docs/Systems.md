# Systems

## Using a Nerves System
**Single Target**

To use a Nerves system in project with a single target, you can directly include it as part of your application dependencies.

```elixir
# mix.exs

def deps do
  [{:nerves_system_bbb, ">=0.0.0"}]
end
```

**Multi Target**

Multi target configurations can be handled a number of ways. You can allow all `nerves_system_*` projects by interpolating `target`
```elixir
def deps(target) do
  [{:"nerves_system_#{target}", ">=0.0.0"}]
end
```

Or you could switch between different configurations of the same target.
```elixir
def deps(:dev = env) do
  [{:my_custom_bbb_dev, ">=0.0.0"}]
end

def deps(:prod = env) do
  [{:my_custom_bbb_prod, ">=0.0.0"}]
end
```

Since its all done in Elixir, you can choose which configuration works best for you. Just be sure that there is only ever one `system` present when compiling your Nerves application.

## Designing a Nerves System

Nerves System dependencies are a collection of configurations to be fed into the the system build platform. Currently, Nerves Systems are all built using the Buildroot platform. The project structure of a Nerves System is as follows:

```
# nerves_system_*
mix.exs
nerves_defconfig
nerves.exs
rootfs-additions
VERSION
```

The mix file will contain the dependencies the System has. Typically, all that is included here is the Toolchain and the build platform. Here is an example of the Raspberry Pi 3 `nerves_system` definition:

```elixir
defmodule NervesSystemRpi3.Mixfile do
  use Mix.Project

  @version Path.join(__DIR__, "VERSION")
    |> File.read!
    |> String.strip

  def project do
    [app: :nerves_system_rpi3,
     version: @version,
     elixir: "~> 1.2",
     compilers: Mix.compilers ++ [:nerves_system],
     description: description,
     package: package,
     deps: deps]
  end

  def application do
   []
  end

  defp deps do
    [{:nerves_system, "~> 0.1.2"},
     {:nerves_system_br, "~> 0.5.0"},
     {:nerves_toolchain_arm_unknown_linux_gnueabihf, "~> 0.6.0"}]
  end

  defp package do
   [maintainers: ["Frank Hunleth", "Justin Schneck"],
    files: ["LICENSE", "mix.exs", "nerves_defconfig", "nerves.exs", "README.md", "VERSION", "rootfs-additions"],
    licenses: ["Apache 2.0"],
    links: %{"Github" => "https://github.com/nerves-project/nerves_system_rpi3"}]
  end

end

```

Nerves Systems have a few requirements in the mix file:
1. The compilers must include the `:nerves_system` compiler after the `Mix.compilers` have executed.
2. There must be a dependency for the toolchain and the build platform.
3. You need to list all files in the `package` `files:` list so they are present when downloading from Hex.

## Package Configuration

In addition to the mix file, Nerves packages read from a special `nerves.exs` configuration file in the root of the package names. This file contains configuration information that Nerves loads before any application or dependency code is compiled. It is used to store metadata about a package. Here is an example from the `nerves.exs` file for `rpi3`:

```
use Mix.Config

version =
  Path.join(__DIR__, "VERSION")
  |> File.read!
  |> String.strip

config :nerves_system_rpi3, :nerves_env,
  type: :system,
  mirrors: [
    "https://github.com/nerves-project/nerves_system_rpi3/releases/download/v#{version}/nerves_system_rpi3-v#{version}.tar.gz"],
  build_platform: Nerves.System.Platforms.BR,
  build_config: [
    defconfig: "nerves_defconfig",
    package_files: [
      "rootfs-additions"
    ]
  ]

```

There are a few important and required keys present in this file:

**type** The type of Nerves Package. Options are: `system`, `system_compiler`, `system_platform`, `system_package`, `toolchain`, `toolchain_compiler`, `toolchain_platform`.

**mirrors** The URL(s) of cached assets. For nerves systems, we upload the finalized assets to Github releases so others can download them.

**build_platform** The build platform to use for the system or toolchain.

**build_config** The collection of configuration files. This collection contains the following keys:

  * **defconfig** For `Nerves.System.Platforms.BR`, this is the Buildroot defconfig fragment used to build the system.

  * **kconfig** Buildroot requires a `Config.in` kconfig file to be present in the config directory. If this is omitted, a default empty file is used.

  * **package_files** Additional files required to be present for the defconfig. Directories listed here will be expanded and all subfiles and directories will be copied over, too.

## Building Nerves Systems

Nerves system dependencies are light-weight, configuration-based dependencies that, at compile time, request to either download from cache, or locally build the dependency. You can control which route `nerves_system` will take by setting some environment variables on your machine:

`NERVES_SYSTEM_CACHE` Options are `none`, `http`, `local`

`NERVES_SYSTEM_COMPILER` Options are `none`, `local`

Currently, Nerves systems can only be compiled using the `local` compiler on a specially-configured Linux machine.

Nerves cache and compiler adhere to the `Nerves.System.Provider` behaviour. Therefore, the system is laid out to allow additional compiler and cache providers, to facilitate other options in the future like Vagrant or Docker. This will be helpful when you want to start a Buildroot build on your Mac or Windows host machine.

### Using Local Cache Provider

Nerves systems can take up a lot of space on your machine. This is because the dependency needs to be fetched for each project | target | env. To save space, you can enable the local cache.

```
$ export NERVES_SYSTEM_CACHE=local
```

With the local cache enabled, Nerves will attempt to find a cached version of the system in the cache dir. The default cache dir is located at `~/.nerves/cache/system` You can override this location by setting `NERVES_SYSTEM_CACHE_DIR` env variable.

If the system your project is attempting to use is not present in the cache, mix will prompt you asking if you would like to download it.

```
$ mix compile
...
==> nerves_system_rpi3
[nerves_system][compile]
[nerves_system][local] Checking Cache for nerves_system_rpi3-0.5.1
nerves_system_rpi3-0.5.1 was not found in your cache.
cache dir: /Users/jschneck/.nerves/cache/system

Would you like to download the system to your cache? [Yn] Y
```

This will invoke the http provider and attempt to resolve the dependency.

## Creating or Modifying a Nerves System with Buildroot

For some applications, the pre-built Nerves Systems won't meet your needs.
For example, you may want to include one or more additional Linux packages or run on hardware that isn't in the list of [Nerves-supported Targets](https://hexdocs.pm/nerves/targets.html) yet.
In order to build a customized system, you'll need to either use Linux (e.g. in a virtual machine or container).

First, make sure that you have all of the dependencies.
On Debian and Ubuntu, run the following:

```
sudo apt-get install git g++ libssl-dev libncurses5-dev bc m4 make unzip cmake
```

Then, set up a working directory.
In the example below, we use the `nerves_build` directory, but this can be anything.
The `nerves_system_br` project contains the base scripts and configuration for using Buildroot with Nerves.
Go to the working directory and clone the repository:

```
mkdir nerves_build
cd nerves_build
git clone https://github.com/nerves-project/nerves_system_br.git
```

While you can start a System build from scratch, it is easiest to modify an existing one and then rename it later when you have something to share or save.
For example, if you're targeting a Raspberry Pi 2, do the following:

```
git clone https://github.com/nerves-project/nerves_system_rpi2.git
```

Once that completes, create an output directory for the build products.
The name of the output directory is up to you, but we will just call it `rpi2_out` in this example.
It is also possible to have multiple output directories if you have several configurations that you would like to work with simultaneously.

```
./nerves_system_br/create-build.sh nerves_system_rpi2/nerves_defconfig rpi2_out

```

The `create-build.sh` script will prompt you with the next steps:

```
cd rpi2_out
make
```

This process will take quite a while (about 30 minutes).
When it finishes, you will have confirmed that you can successfully build the standard `rpi2` System.
The next section will describe how to make changes and re-build the System.

If you ever update `nerves_system_br`, be sure to run the `create-build.sh` script again.
You can point it to the same location and it will update properly.
It is best to `make clean` and then `make` to rebuild everything after updating `nerves_system_br`.

### Additional Package Configuration

The workflow for customizing a Nerves System is the standard Buildroot procedure using `make menuconfig`.
The packages are divided into three categories:

  1. Select base packages by running `make menuconfig`
  2. Modify the Linux kernel and kernel modules with `make linux-menuconfig`
  3. Enable more command line utilities using `make busybox-menuconfig`

If you followed the steps in the previous section, make sure you have changed directory to `rpi2_out` first.

When you quit from the `menuconfig` interface, the changes are stored temporarily.
To save them back in your System, follow the appropriate steps below:

  1. Run `make savedefconfig` after `make menuconfig` to update the `nerves_defconfig` in your System.
  2. Run `make linux-savedefconfig` and `cp build/linux-x.y.z/defconfig <your system>` after `make linux-menuconfig`.
     If your system doesn't contain a custom Linux configuration yet, you'll need to update the
     Buildroot configuration to point to the new Linux defconfig in your system directory.
     The path is usually something like `$(NERVES_DEFCONFIG_DIR)/linux-x.y_defconfig`.
  3. For Busybox, the convention is to copy `build/busybox-x.y.z/.config` to a file in the System repository.
     Like the Linux configuration, the Buildroot configuration will need to be updated to point to the
     custom config.

The Buildroot [user manual](http://nightly.buildroot.org/manual.html) can be very helpful especially if you need to add a package.
The various Nerves System repositories have examples of many common use cases, so check them out as well.

### How to Use Your New System

By default, Nerves downloads pre-built Systems from the Internet and caches them on your hard drive.
To force a local build and not cache (so you can re-build it), set the following environment variables:

```
NERVES_SYSTEM_CACHE=none
NERVES_SYSTEM_COMPILER=local
```

To use your new System in your firmware build, specify it with the `NERVES_SYSTEM` environment variable.
Assuming you followed the steps in the previous section, you can do this:

```
cd rpi2_out
export NERVES_SYSTEM=$PWD
```

Then, when you do the `mix firmware` step from your project directory, your custom System will be used.
Make sure you still specify the matching `NERVES_TARGET` (`rpi2` in this example) in your project's `mix.exs` configuration, since it won't be automatically detected for a custom System like this.

Once you're happy with your System, you can package it by changing to the `rpi2_out` directory and running:

```
make system
```

This will create a `<system>.tar.gz` file that can be hosted on a web server and referenced from a Hex package just like the official Nerves Systems are.

### Supporting New Target Hardware

If you're trying to support a new Target, there may be quite a bit more work involved, depending on how mature the support for that hardware is in the Buildroot community.
If you're not familiar with [Buildroot](https://buildroot.org/), you should learn about that first, using the excellent training materials on their website.

If you can find an existing Buildroot configuration for your intended hardware and you want to get it working with Nerves:

1.  Follow their procedure and confirm your target boots (independent of Nerves).

2.  Figure out how to get everything working with the version of Buildroot Nerves uses. See [the `NERVES_BR_VERSION` variable in `create-build.sh`](https://github.com/nerves-project/nerves_system_br/blob/master/create-build.sh).

  * Look for packages and board configs can need to be copied into your System.
  * Look for patches to existing packages that are needed.

3. Create a defconfig that mimics the one from step 1, and get `nerves_system_br` to build it.

> NOTE: You probably want to disable any userland packages that may be included by default to avoid distraction.

