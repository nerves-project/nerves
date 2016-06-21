## Systems

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

  * **defconfig** For `Nerves.System.Platforms.BR`, this is the BuildRoot defconfig fragment used to build the system.

  * **kconfig** BuildRoot requires a `Config.in` kconfig file to be present in the config directory. If this is omitted, a default empty file is used.

  * **package_files** Additional files required to be present for the defconfig. Directories listed here will be expanded and all subfiles and directories will be copied over, too.

## Building Nerves Systems

Nerves system dependencies are light-weight, configuration-based dependencies that, at compile time, request to either download from cache, or locally build the dependency. You can control which route `nerves_system` will take by setting some environment variables on your machine:

`NERVES_SYSTEM_CACHE` Options are `none`, `http`, `local`

`NERVES_SYSTEM_COMPILER` Options are `none`, `local`

Currently, Nerves systems can only be compiled using the `local` compiler on a specially-configured Linux machine. For more information on what is required to set up your host Linux machine, you can read the `nerves_system_br` [Install Page](https://github.com/nerves-project/nerves_system_br/blob/master/README.md)

Nerves cache and compiler adhere to the `Nerves.System.Provider` behaviour. Therefore, the system is laid out to allow additional compiler and cache providers, to facilitate other options in the future like Vagrant or Docker. This will be helpful when you want to start a BuildRoot build on your Mac or Windows host machine.

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

## Creating or Modifying a Nerves System

The easiest way to create a new Nerves system is to check out [`nerves_system_br`](https://github.com/nerves-project/nerves_system_br) and create a configuration that contains the packages and configuration you need. Once you get this working and booting on your target, you can copy the configurations and files back into a new mix project following the structure described above.
