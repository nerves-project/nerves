# Systems

## Using a Nerves System

When you generate a new Nerves project using the `mix nerves.new` task, you will end up with the following section in your `mix.exs` configuration:

```elixir
  @target System.get_env("MIX_TARGET") || "host"

  [...]

  def deps do
    [...]
    deps(@target)
  end

  # Specify target specific dependencies
  def deps("host"), do: []
  def deps(target) do
    [{:"nerves_system_#{target}", ">= 0.0.0"}]
  end
```

This allows Nerves to load one or more Target-specific dependencies when a `MIX_TARGET` is specificied.
The official `nerves_system-*` dependencies contain the standard Buildroot configuration for the Nerves platform on a given hardware target and have a dependency on the appropriate Toolchain for that target.
The System and Toolchain also reference a pre-compiled version of the relevant Artifact so that Mix can simply download them instead of having to compile them (which takes quite a while).

## Anatomy of a Nerves System

Nerves System dependencies are a collection of configurations to be fed into the the system build platform.
Currently, Nerves Systems are all built using the Buildroot platform.
The project structure of a Nerves System is as follows:

```plain
nerves_system_rpi3
├── LICENSE
├── README.md
├── VERSION
├── cmdline.txt
├── config.txt
├── fwup.conf
├── linux-4.4.defconfig
├── mix.exs
├── nerves.exs
├── nerves_defconfig
├── post-createfs.sh
└── rootfs-additions
    ├── etc
    │   └── erlinit.config
    └── lib
        └── firmware
```

The `mix.exs` defines the Toolchain and build platform.
Here is an example from `nerves_system_rpi3`:

```elixir
def project do
  [[...]
   compilers: Mix.compilers ++ [:nerves_package],
   aliases: ["deps.precompile": ["nerves.env", "deps.precompile"]]]
end

defp deps do
  [{:nerves, "~> 0.4.0"},
   {:nerves_system_br, "~> 0.9.2"},
   {:nerves_toolchain_arm_unknown_linux_gnueabihf, "~> 0.9.0"}]
end
```

Nerves Systems have a few requirements in the mix file:
1. The compilers must include the `:nerves_system` compiler after the `Mix.compilers` have executed.
2. There must be a dependency for the Toolchain and the build platform.
3. You need to list all files in the `package` `files:` list so they are present when downloading from Hex.

## Package Configuration

In addition to the mix file, Nerves packages read from a special `nerves.exs` configuration file in the root of the package names.
This file contains configuration information that Nerves loads before any application or dependency code is compiled.
It is used to store metadata about a package.
Here is an example from the `nerves.exs` file for `nerves_system_rpi3`:

```elixir
use Mix.Config

version =
  Path.join(__DIR__, "VERSION")
  |> File.read!
  |> String.strip

pkg = :nerves_system_rpi3

config pkg, :nerves_env,
  type: :system,
  version: version,
  compiler: :nerves_package,
  artifact_url: [
    "https://github.com/nerves-project/#{pkg}/releases/download/v#{version}/#{pkg}-v#{version}.tar.gz",
  ],
  platform: Nerves.System.BR,
  platform_config: [
    defconfig: "nerves_defconfig",
  ],
  checksum: [
    "nerves_defconfig",
    "rootfs-additions",
    "linux-4.4.defconfig",
    "fwup.conf",
    "cmdline.txt",
    "config.txt",
    "post-createfs.sh",
    "VERSION"
  ]
```

There are a few important and required keys present in this file:

`type`: The type of Nerves Package.
Options are: `system`, `system_compiler`, `system_platform`, `system_package`, `toolchain`, `toolchain_compiler`, `toolchain_platform`.

`artifact_url`: The URL(s) of cached assets.
For Nerves Systems and Toolchains, we upload the Artifacts to GitHub Releases.

`platform`: The build platform to use for the System or Toolchain.

`platform_config`: Configuration options for the build platform.
In this example, the `defconfig` option for `Nerves.System.Platforms.BR` points to the Buildroot defconfig fragment file used to build the System.

`checksum`: The list of files for which checksums are calculated and stored in the Artifact cache.
This checksum is used to match the cached Nerves Artifact on disk with its source files, so that it will be re-compiled instead of using the cache if the source files no longer match.

## Creating or Modifying a Nerves System with Buildroot

For some applications, the pre-built Nerves Systems won't meet your needs.
For example, you may want to include additional Linux packages or run on hardware that isn't in the list of [Nerves-supported Targets](https://hexdocs.pm/nerves/targets.html) yet.
In order to build a customized system, you'll need to use Linux, either natively, in virtual machine, or in a container.

### Building on Linux

First, make sure that you have all of the dependencies.
On Debian and Ubuntu, run the following:

```bash
sudo apt-get install git g++ libssl-dev libncurses5-dev bc m4 make unzip cmake
```

Then, set up a working directory.
In the example below, we use the `nerves_build` directory, but this can be anything.
The `nerves_system_br` project contains the base scripts and configuration for using Buildroot with Nerves.
Go to the working directory and clone the repository:

```bash
mkdir nerves_build
cd nerves_build
git clone https://github.com/nerves-project/nerves_system_br.git
```

While you can start a System build from scratch, it is easiest to modify an existing one and then rename it later when you have something to share or save.
For example, if you're targeting a Raspberry Pi 3, do the following:

```bash
git clone https://github.com/nerves-project/nerves_system_rpi3.git
```

Once that completes, create an output directory for the build products.
The name of the output directory is up to you, but we will just call it `custom_rpi3` in this example.
It is also possible to have multiple output directories if you have several configurations that you would like to work with simultaneously.

```bash
./nerves_system_br/create-build.sh nerves_system_rpi3/nerves_defconfig custom_rpi3

```

The `create-build.sh` script will prompt you with the next steps:

```bash
cd custom_rpi3
make
```

This process will take quite a while (about 30 minutes).
When it finishes, you will have confirmed that you can successfully build an equivalent of the standard `rpi3` System.
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

To use your new System in your firmware build, specify it with the `NERVES_SYSTEM` environment variable.
Assuming you followed the steps in the previous section, you can do this:

```bash
cd custom_rpi3
export NERVES_SYSTEM=$PWD
```

Then, when you do the `mix firmware` step from your project directory, your custom System will be used.
Make sure you still specify the appropriate `MIX_TARGET` (`rpi3` in this example) in your environment when you run `mix deps.get` and `mix firmware` because it will not be detected automatically for custom Systems.

Once you're happy with your System, you can package it by changing to the `custom_rpi3` directory and running:

```bash
make system
```

This will create a `<system>.tar.gz` file that can be hosted on a web server and referenced from a Hex package just like the official Nerves Systems are.

