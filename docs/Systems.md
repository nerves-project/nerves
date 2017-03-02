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
1. The `compilers` must include the `:nerves_system` compiler after the `Mix.compilers` have executed.
2. There must be a dependency for the Toolchain and the build platform.
3. You need to list all files in the `package` `files:` list so they are present when downloading from Hex.

## Package Configuration

In addition to the mix file, Nerves packages read from a special `nerves.exs` configuration file in the root of the package directory.
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

There are a few required keys in this file:

`type`: The type of Nerves Package.
Options are: `system`, `system_compiler`, `system_platform`, `system_package`, `toolchain`, `toolchain_compiler`, `toolchain_platform`.

`artifact_url`: The URL(s) of cached assets.
For official Nerves Systems and Toolchains, we upload the Artifacts to GitHub Releases.

`platform`: The build platform to use for the System or Toolchain.

`platform_config`: Configuration options for the build platform.
In this example, the `defconfig` option for `Nerves.System.Platforms.BR` points to the Buildroot defconfig fragment file used to build the System.

`checksum`: The list of files for which checksums are calculated and stored in the Artifact cache.
This checksum is used to match the cached Nerves Artifact on disk with its source files, so that it will be re-compiled instead of using the cache if the source files no longer match.

## Customizing Your Own Nerves System

For some applications, the pre-built Nerves Systems won't meet your needs.
For example, you may want to include additional Linux packages or run on hardware that isn't in the list of [Nerves-supported Targets](https://hexdocs.pm/nerves/targets.html) yet.
In order to make the build process consistent across host platforms, Nerves uses a Docker container behind the scenes to perform the build on non-Linux hosts.
This makes it possible for the steps below to apply to whatever host platform you're using for development, as long as you have Docker for Mac or Docker for Windows installed on those platforms.

While you could design a System from scratch, it is easiest to copy and modify an existing one, renaming it to distinguish it from the official release.
For example, if you're targeting a Raspberry Pi 3 board, do the following:

```bash
$ git clone https://github.com/nerves-project/nerves_system_rpi3.git
$ mv nerves_system_rpi3 custom_rpi3
```

The name of the System directory is up to you, but we will just call it `custom_rpi3` in this example.
It's recommended that you check your custom System into your version control system before making changes.
This makes it easier to merge in upstream changes from the official Systems.

```bash
# After creating an empty custom_rpi3 repository in your GitHub account

$ cd custom_rpi3
$ git remote rename origin upstream
$ git remote add origin git@github.com:YourGitHubUserName/custom_rpi3.git
$ git push origin master
```

Next, tweak the metadata for your System so it won't conflict with the official one:

```elixir
# custom_rpi3/nerves.exs
use Mix.Config

# =vvv= Update the package name and remove (or replace) the artifact_url list

pkg = :custom_rpi3

config pkg, :nerves_env,
  type: :system,
  version: version,
  compiler: :nerves_package,
#   artifact_url: [
#     "...",
#   ],
    platform: Nerves.System.BR,
    platform_config: [
      defconfig: "nerves_defconfig"
    ],

# =^^^=

...
```

```elixir
# custom_rpi3/mix.exs

# =vvv= Update the module and application names
defmodule CustomRpi3.Mixfile do

  ...

  def project do
   [app: :custom_rpi3,
    version: @version,
    ...
  end
# =^^^=

...

# =vvv= Update the maintainer and project information
  defp package do
   [maintainers: ["Your Name"],
    files: [...],
    licenses: ["Your License"],
    links: %{"Github" => "https://github.com/YourGitHubUserName/custom_rpi3"}]
  end
# =^^^=
end
```

Now that the custom System directory is prepared, you just need to point to it from your project's `mix.exs`.

```elixir
# your_project/mix.exs

# Specify target specific dependencies
def deps("host"), do: []
# =vvv= Add this section for your custom System
def deps("custom_rpi3") do
  [{:custom_rpi3, path: "/path/to/your/custom_rpi3"}]
end
# =^^^=
def deps(target) do
  [{:"nerves_system_#{target}", ">= 0.0.0"}]
end
```

Set your `MIX_TARGET` to refer to your custom system and build your firmware.

```bash
$ cd /path/to/your/nerves/project
$ export MIX_TARGET=custom_rpi3
$ mix deps.get
$ mix firmware
```

This process will take quite a bit longer than a normal firmware build (15 to 30 minutes) the first time.
When it finishes, you will have confirmed that you can successfully build an equivalent of the standard `rpi3` System.
After your custom System has been built, you can modify your application and re-build firmware normally.
The custom System will automatically re-build if you make changes to the System itself.

## Package Configuration

> NOTE: Currently, the following process only works on Linux.
> We're working on a method to make this work via Docker, but it's not ready yet.
> You can still modify the various `defconfig` fragments manually, if you know what you're doing, but the simpler `make menuconfig` process currently won't work.

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
