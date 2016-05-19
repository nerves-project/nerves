## Systems

Nerves system dependencies are a collection of configurations to be fed into the the system build platform. Currently, Nerves Systems are all build from the Buildroot build platform. The project structure of Nerves Systems is as follows

```
# nerves_system_*
mix.exs
nerves_defconfig
nerves.exs
rootfs-additions
VERSION
```

The mix file will contain the dependencies the system has. Typically, all that is included here is the toolchain and the build platform. Here is an example of the raspberry pi 3 nerves_system

```
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

Nerves systems have a few requirements in the mix file. First, the compilers must include the `:nerves_system` compiler after the `Mix.compilers` have executed. Next, they must contain the dependency for the toolchain and the build platform. It is also important to note that when pushing this to hex, you will need to list all files in the package files so they are present when downloading.

## Package Configuration

In addition to the mix file. nerves packages read form a special configuration file in the root of the package names `nerves.exs`. This file contains configuration information which Nerves will load before any application or dependency code is compiled. It is used to store metadata about a package. Here is an example from the rpi3 nerves.exs

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

There are a few important and required keys present in this file.

**type** The type of Nerves Package. Options are: `system`, `system_compiler`, `system_platform`, `system_package`, `toolchain`, `toolchain_compiler`, `toolchain_platform`

**mirrors** The urls of the location of cached assets. For nerves systems, we upload the finalized assets to Github releases so others can download them.

**build_platform** The build platform to use for the system or toolchain

**build_config** The collection of configuration files. This collection contains the following keys

  **defconfig** For `Nerves.System.Platforms.BR` this is the defconfig fragment used to build the system

  **kconfig** buildroot requires a `Config.in` kconfig file to be present in the config directory. If this is omitted, a default empty file is used.

  **package_files** Additional files required to be present for the defconfig. Directorys listed here will be expanded and all subfiles and directories will be copied over too.

## Building Nerves Systems

Nerves system dependencies are light weight, configuration based dependencies which at compile time request to either download from cache, or locally build the dependency. You can control which route nerves_system will take by setting some environment variables on your machine

`NERVES_SYSTEM_CACHE` Options are `none`, `http`

`NERVES_SYSTEM_COMPILER` Options are `none`, `local`

Currently, Nerves systems can only be compiled using the `local` compiler on a specially configured linux machine. For more information on what is required to set up your host linux machine you can read the nerves_system_br [Install Page](https://github.com/nerves-project/nerves_system_br/blob/master/README.md)

Nerves cache and compiler adhere to the `Nerves.System.Provider` behaviour. Therefore, the system is laid out to allow additional compiler and cache providers to facilitate the requests like Vagrant or Docker. This will be helpful kin the future when you want to start a buildroot build on your Mac or Windows host machine.

## Creating or Modifying a Nerves System

The easiest way to create a new nerves system is to check out [nerves_system_br](https://github.com/nerves-project/nerves_system_br) and create a configuration which contains the packages and configuration you need. Once you get this working and booting on your target you can copy the configurations and files back into a new mix project following the structure described above.
