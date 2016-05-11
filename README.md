# Nerves
Craft bulletproof firmware in the stunningly productive Elixir language

## Requirements

64-bit host running
* Mac OS 10.10+ or Linux (We've tested on Debian / Ubuntu / Redhat / CentOS)
* Elixir ~> 1.2.4 or ~> 1.3
* [fwup](https://github.com/fhunleth/fwup) >= 0.6.1

## Installation

### Bootstrap Archive

Nerves is a suite of components which work together to create reproducible firmware using the Elixir programming language. To build Nerves applications on your machine, you will first be required to install the Nerves Bootstrap archive. The Nerves Bootstrap archive contains mix hooks required to bootstrap your mix environment to properly cross compile your application and dependency code for the Nerves target.

To install the archive:
```
$ mix archive.install https://github.com/nerves-project/archives/raw/master/nerves_bootstrap.ez
```
If the Nerves Bootstrap archive does not install properly, you can download the file from github directly and then install using the command `mix archive.install /path/to/local/nerves_bootstrap.ez`

In addition to the archive, you will need to include the `:nerves` application in your application deps and applications list.

  1. Add nerves to your list of dependencies in `mix.exs`:

        def deps do
          [{:nerves, "~> 0.3"}]
        end

  2. Ensure nerves is started before your application:

        def application do
          [applications: [:nerves]]
        end

## Project Configuration
You can generate a new nerves project using the project generator. You are required to pass a target tag to the generator. You can find more information about target tags for your board at  http://nerves-project.org

`mix nerves.new my_app --target rpi2`

### Building Firmware

Now that everything is installed and configured its time to make some firmware. Here is the workflow

`mix deps.get` - Fetch the dependencies.

`mix compile` - Bootstrap the Nerves Env and compile the App.

`mix firmware` - Creates a fw file

`mix firmware.burn` - Burn firmware to an inserted SD card.


## Build System Details

### Mix

Embedding nerves into mix allows us nicely handle a variety of configurations from basic to advanced. Part of this involves handling multi-target builds. First lets talk about how to configure a mix file for Nerves.

Nerves applications require some additional project configurations to be made for the environment to function properly. Lets take a look at some of these in this sample mix file.
```
defmodule Blinky.Mixfile do
  use Mix.Project

  @target System.get_env("NERVES_TARGET") || "rpi2"

  def project do
    [app: :blinky,
     version: "0.1.0",
     archives: [nerves_bootstrap: "~> 0.1"],
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     target: @target,
     deps_path: "deps/#{@target}",
     build_path: "_build/#{@target}",
     config_path: "config/#{@target}/config.exs",
     aliases: aliases,
     deps: deps ++ system(@target)]
  end

  def application do
    [applications: [:nerves, :logger, :nerves_io_led],
     mod: {Blinky, []}]
  end

  defp deps, do: [
    {:nerves, github: "nerves-project/nerves"},
    {:nerves_io_led, github: "nerves-project/nerves_io_led"}
  ]

  def system("bbb") do
    [{:nerves_system_bbb, github: "nerves-project/nerves_system_bbb"}]
  end

  def system("rpi2") do
    [{:nerves_system_rpi2, github: "nerves-project/nerves_system_rpi2"}]
  end

  def aliases do
    ["deps.precompile": ["nerves.precompile", "deps.precompile"],
     "deps.loadpaths":  ["deps.loadpaths", "nerves.loadpaths"]]
  end

end
```

Starting from the top down, lets break apart whats going on here.

**Target**

First, we expose a mechanism for passing the target string into the file. This target is a string that we use to refer to different common configurations of boards, example: rpi, rpi2, rpi3, bbb.

`@target System.get_env("NERVES_TARGET") || "rpi2"`

In this configuration we are saying that the user must specify the target by setting or passing the environment variable `NERVES_TARGET`. The configuration is also stating that if a target is not passed or defined that the project will choose the default target of rpi2. Since it is just required that the module attribute `@target` is set to an actual target string value, and that this is just elixir code, the user can decide to hardcode a single target here, or omit the project default target.

To switch targets on the fly, the user can call any mix command with
```
$ NERVES_TARGET=bbb mix deps.get
```

**The Project Config**

`archives: [nerves_bootstrap: "~> 0.1"]` - Inform Elixir that the user is required to have the `:nerves_bootstrap` archive installed.

`target: @target` - Nerves requires to have access to the target in later stages of firmware production. This is due to organization of configurations and artifacts on disk  .

**Paths**

```
deps_path: "deps/#{@target}",
build_path: "_build/#{@target}",
config_path: "config/#{@target}/config.exs",
```
In order to sanitize the compiled code we separate all paths by target. This prevents errors that could occur if dependencies or builds of configs are shared between targets of different architectures.

`deps: deps ++ system(@target)` - Dependencies are also separated by target. In this setup, we have shared dependencies from `deps/0` and system specific dependencies included from `system/1`. This is important because the Nerves system compiler will require that only 1 system configuration is present at all times.

`aliases: aliases` - Aliases are Nerves way of bootstrapping the mix project lifecycle.
The following aliases are required to be specified.
```
def aliases do
  ["deps.precompile": ["nerves.precompile", "deps.precompile"],
   "deps.loadpaths":  ["deps.loadpaths", "nerves.loadpaths"]]
end
```
These aliases hook into the mix project lifecycle at two locations, `precompile` and `loadpaths`. These hooks ensure that the first dependency to be compiled is the system. The precompile task makes the assumption that `:nerves_system` has been fetched, locates it on disk, and forces it to be the first app to get compiled. Once `:nerves_system` is compiled, it initializes the `Nerves.Env`, a module responsible for globally loading package configuration metadata about Nerves dependencies without loading or compiling them.

### Nerves Package Configuration
The package configuration file should be placed in the root of the dependency source directory and called `nerves.exs`. The file should `use Mix.Config` and should contain configuration information about the package.

For example, when describing the system configuration for a Raspberry Pi 2 Target
```
use Mix.Config

config :nerves_system_rpi2, :nerves_env,
  type:  :system,
  mirrors: [
    "https://github.com/nerves-project/nerves_system_rpi2/releases/download/v#{version}/nerves_system_rpi2-v#{version}.tar.gz"],
  build_platform: Nerves.System.Platforms.BR,
  build_config: [
    defconfig: "nerves_defconfig"
  ]
```

Lets take a look at some of these values

`type: :system` - (required) The type tells the Env what kind of package it is.
The following are types and a common example of what they are
  * `system` - A project containing system configurations, usually specified in its `ext: [defconfig: "path/to/defconfig"]`
  * `system_ext` - project containing defconfig and or rootfs-additions to extend a base system. For example, `nerves_bluetooth` can have a defconfig which just contains lines to append to the system defconfig.
  * `system_platform` - project containg the scripts required to actually build the system. Currently we only support the `Nerves.System.Platforms.BR` or Buildroot platform.
  * `system_compiler` - Almost always `nerves_system`
  * `toolchain` - A project containg toolchain configurations for a variety of hosts for a target platform / arch.
  * `toolchain_compiler` - Almost always `nerves_toolchain`

Package configurations can also contain type specific items for use during the mix lifecycle. The following are an example of common extra configurations for types.

`system` and `system_ext`
ext is a keyword list with keys for defconfig and rootfs_additions pointing to their location relative to the root of the dependency.
```
ext: [
  defconfig: "nerves_defconfig",
  rootfs_additions: "rootfs-additions"
]
```

`build_platform: Nerves.System.Platforms.BR` - The build platform will point to a module which which uses the `Nerves.System.Platform` behaviour.

### Env Variables

You can configure which cache / compile providers the system and toolchain should use when building. The following are environment variables which you can set.

`NERVES_SYSTEM_CACHE` - The cache provider to use
Options
  * `none` - Do not use a cache provider. This will force the system to compile instead of pulling from cache.
  * `http` - Use the http cache provider. This provider will use the list of mirrors from the configuration.

`NERVES_SYSTEM_COMPILER` - The compiler provider to use
Options
  * `local` - Linux only. This will compile the system locally.
  * `none` - Will not compile the system. You will be sad.
