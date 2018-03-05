# Systems

## Using a Nerves System

When you generate a new Nerves project using the `mix nerves.new` task, you will
end up with something like the following in your `mix.exs` configuration:

```elixir
  # ...
  @target System.get_env("MIX_TARGET") || "host"
  # ...
  def deps do
    [{:nerves, "~> 1.0-rc", runtime: false}] ++
    deps(@target)
  end

  # Specify target specific dependencies
  def deps("host"), do: []
  def deps(target) do
    [ system(target),
      # ...
    ]
  end

  def system("rpi"), do: {:nerves_system_rpi, ">= 0.0.0", runtime: false}
  def system("rpi0"), do: {:nerves_system_rpi0, ">= 0.0.0", runtime: false}
  # ...
  def system(target), do: Mix.raise "Unknown MIX_TARGET: #{target}"
```

This allows Nerves to load one or more target-specific dependencies when a
`MIX_TARGET` system environment variable is specified. The official
`nerves_system-*` dependencies contain the standard Buildroot configuration for
the Nerves platform on a given hardware target and have a dependency on the
appropriate toolchain for that target. The system and toolchain also reference a
pre-compiled version of the relevant artifact so that Mix can simply download
them instead of having to compile them (which takes quite a while).

## Anatomy of a Nerves System

Nerves system dependencies are a collection of configurations to be fed into the
the system build platform. Currently, Nerves systems are all built using the
Buildroot platform. The project structure of a Nerves system is as follows:

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
├── nerves_defconfig
├── post-createfs.sh
└── rootfs-overlay
    └── etc
        └── erlinit.config
        └── fw_env.config
```

The `mix.exs` defines the toolchain and build platform, for example:

```elixir
def project do
  [ # ...
   nerves_package: nerves_package(),
   compilers: Mix.compilers ++ [:nerves_package],
   aliases: ["deps.precompile": ["nerves.env", "deps.precompile"]]]
end
# ...
def nerves_package do
  [
    type: :system,
    artifact_url: [
      "https://github.com/nerves-project/#{@app}/releases/download/v#{@version}/#{@app}-v#{@version}.tar.gz",
    ],
    platform: Nerves.System.BR,
    platform_config: [
      defconfig: "nerves_defconfig"
    ],
    checksum: [
      "nerves_defconfig",
      "rootfs_overlay",
      "linux-4.4.defconfig",
      "fwup.conf",
      "cmdline.txt",
      "config.txt",
      "post-createfs.sh",
      "VERSION"
    ]
  ]
end
# ...
defp deps do
  [
    {:nerves, "~> 1.0-rc", runtime: false},
    {:nerves_system_br, "~> 1.0-rc", runtime: false},
    {:nerves_toolchain_arm_unknown_linux_gnueabihf, "~> 1.0-rc", runtime: false}
  ]
end
# ...
defp package do
 [ # ...
  files: ["LICENSE", "mix.exs", "<other files>"],
  licenses: ["Apache 2.0"],
  links: %{"Github" => "https://github.com/nerves-project/nerves_system_rpi3"}]
end
```

Nerves systems have a few requirements in the mix file:

1. The `compilers` must include `:nerves_system` compiler after `Mix.compilers`.
2. There must be a dependency for the toolchain and the build platform.
3. The `package` must specify all the required `files` so they are present when
   downloading from Hex.
4. The `nerves_package` key should contain nerves package configuration metadata as
   described in the next section.

## Package Configuration

The `mix.exs` project configuration contains a special configuration key `nerves_package`. This key
contains configuration information that Nerves loads before any application or
dependency code is compiled. It is used to store metadata about a package. Here
is an example from the `mix.exs` file for `nerves_system_rpi3`:

```elixir
# ...
def project do
  [ # ...
   nerves_package: nerves_package(),
    # ...
  ]
end
# ....
def nerves_package do
  [
    type: :system,
    artifact_url: [
      "https://github.com/nerves-project/#{@app}/releases/download/v#{@version}/#{@app}-v#{@version}.tar.gz",
    ],
    platform: Nerves.System.BR,
    platform_config: [
      defconfig: "nerves_defconfig"
    ],
    checksum: [
      "nerves_defconfig",
      "rootfs_overlay",
      "linux-4.4.defconfig",
      "fwup.conf",
      "cmdline.txt",
      "config.txt",
      "post-createfs.sh",
      "VERSION"
    ]
  ]
end
```

The following keys are supported:

1. `type`: The type of Nerves Package.

    Options are: `system`, `system_compiler`, `system_platform`,
    `system_package`, `toolchain`, `toolchain_compiler`, `toolchain_platform`.

2. `artifact_url` (optional): The URL(s) of cached assets.

    For official Nerves systems and toolchains, we upload the artifacts to
    GitHub Releases.

3. `platform`: The build platform to use for the system or toolchain.

4. `platform_config`: Configuration options for the build platform.

    In this example, the `defconfig` option for the `Nerves.System.BR`
    platform points to the Buildroot defconfig fragment file used to build the
    system.

5. `provider`: Optional - The provider that should be used to build the artifact.

    If this key is not defined, Nerves will choose a default provider
    that should be used to build the artifact based on information about the host
    computer that you are building on. For example, Mac OS will use
    `Nerves.Artifact.Providers.Docker` where as Linux will use
    `Nerves.Artifact.Providers.Local`. Specifying a provider module in
    the package config could be used to force the provider.

6. `provider_opts`: Optional - A keyword list of options to pass to the provider module.

7. `checksum`: The list of files for which checksums are calculated and stored
    in the artifact cache.

    This checksum is used to match the cached Nerves artifact on disk with its
    source files, so that it will be re-compiled instead of using the cache if
    the source files no longer match.

## Customizing Your Own Nerves System

For some applications, the pre-built Nerves Systems won't meet your needs. For
example, you may want to include additional Linux packages or run on hardware
that isn't in the list of [Nerves-supported
targets](https://hexdocs.pm/nerves/targets.html) yet. In order to make the build
process consistent across host platforms, Nerves uses a Docker container behind
the scenes to perform the build on non-Linux hosts. This makes it possible for
the steps below to apply to whatever host platform you're using for development,
as long as you have Docker for Mac or Docker for Windows installed on those
platforms.

While you could design a system from scratch, it is easiest to copy and modify
an existing one, renaming it to distinguish it from the official release. For
example, if you're targeting a Raspberry Pi 3 board, do the following:

```bash
git clone https://github.com/nerves-project/nerves_system_rpi3.git custom_rpi3
```

The name of the system directory is up to you, but we will call it `custom_rpi3`
in this example. It's recommended that you check your custom system into your
version control system before making changes. This makes it easier to merge in
upstream changes from the official systems later. For example, assuming you're
using GitHub:

```bash
# After creating an empty custom_rpi3 repository in your GitHub account

cd custom_rpi3
git remote rename origin upstream
git remote add origin git@github.com:YourGitHubUserName/custom_rpi3.git
git push origin master
```

Next, tweak the metadata for your system so it won't conflict with the official
one and won't try to download a cached artifact that doesn't exist yet:

```elixir
# custom_rpi3/mix.exs
# ...
def nerves_package do
  [
    type: :system,
    # artifact_url: [
    #   "https://github.com/nerves-project/#{@app}/releases/download/v#{@version}/#{@app}-v#{@version}.tar.gz",
    # ],
    platform: Nerves.System.BR,
    platform_config: [
      defconfig: "nerves_defconfig"
    ],
    checksum: [
      "nerves_defconfig",
      "rootfs_overlay",
      "linux-4.4.defconfig",
      "fwup.conf",
      "cmdline.txt",
      "config.txt",
      "post-createfs.sh",
      "VERSION"
    ]
  ]
end
# ...
```

```elixir
# custom_rpi3/mix.exs

# =vvv= Update the module and application names
defmodule CustomRpi3.Mixfile do

  # ...

  def project do
   [app: :custom_rpi3,
    version: @version,
    # ...
  end
# =^^^=

# ...

# =vvv= Update the maintainer and project information
  defp package do
   [maintainers: ["Your Name"],
    # ...
    links: %{"Github" => "https://github.com/YourGitHubUserName/custom_rpi3"}]
  end
# =^^^=
end
```

Now that the custom system directory is prepared, you just need to point to it
from your project's `mix.exs`. In this example, we assume that your
`custom_rpi3` system directory is in the same directory as your nerves firmware
project directory, like so:

```plain
~/projects
├── custom_rpi3
└── your_project
```

```elixir
# your_project/mix.exs

  # ...
  def system("rpi3"), do: [{:nerves_system_rpi3, ">= 0.0.0", runtime: false}]
  def system("custom_rpi3"), do: [{:custom_rpi3, path: "../custom_rpi3", runtime: false}]
  def system(target), do: Mix.raise "Unknown MIX_TARGET: #{target}"
```

Set your `MIX_TARGET` to refer to your custom system and build your firmware.

```bash
cd ~/projects/your_project
export MIX_TARGET=custom_rpi3
mix deps.get
mix firmware
```

This process will take quite a bit longer than a normal firmware build (15 to 30
minutes) the first time. When it finishes, you will have confirmed that you can
successfully build an equivalent of the official `rpi3` system. After your
custom system has been built, you can modify your application and re-build
firmware normally. The custom system will only re-build if you make changes to
the system source project itself.

## Package Configuration

Because Buildroot can only be used from Linux, Nerves provides an abstraction
layer called the Nerves system configuration shell that allows the same
procedure to be used on Linux and non-Linux development hosts by using a
Linux-based Docker container on non-Linux platforms. To access this environment,
run the `mix nerves.system.shell` task, either from your project directory or
from the custom system source directory.

```bash
$ export MIX_TARGET=rpi3
$ mix deps.get
Mix environment
 MIX_TARGET:   rpi3
 MIX_ENV:      dev

Running dependency resolution...
Dependency resolution completed:
<-SNIP->
* Getting nerves (Hex package)
 Checking package (https://repo.hex.pm/tarballs/nerves-0.7.0.tar)
<-SNIP->

$ mix nerves.system.shell
Mix environment
 MIX_TARGET:   custom_rpi3
 MIX_ENV:      dev

==> distillery
Compiling 19 files (.ex)
Generated distillery app
==> nerves
Compiling 25 files (.ex)
Generated nerves app

 Preparing Nerves Shell

Creating build directory...
Cleaning up...
Nerves  /nerves/build >
```

Once at the `Nerves  /nerves/build >` shell prompt, the workflow for customizing
a Nerves system is the same as when using Buildroot outside of Nerves, using
`make menuconfig` and `make savedefconfig`. Remember that this is effectively a
sub-shell on both Linux and non-Linux platforms, so when you're finished
updating the configuration and optionally re-building the system "manually", you
can get back to your normal shell by typing `exit` or pressing `CTRL+D`.

The main package configuration workflows are divided into three categories,
depending on what you want to configure:

1. Select base packages by running `make menuconfig`
2. Modify the Linux kernel and kernel modules with `make linux-menuconfig`
3. Enable more command line utilities using `make busybox-menuconfig`

> NOTE: You can build the system "manually" using `make` from inside the system
configuration shell if you want to iterate quickly while trying out different
changes. When you're ready to try out the system in your project, exit the shell
and have `mix firmware` take care of the re-build for you from your project
directory. Please be aware that Buildroot does not handle incremental
compilation well, so it's recommended that you always run `make clean` before
`make` unless you're experienced with Buildroot and understand when you can skip
the `make clean` step.

When you quit from the `menuconfig` interface, the changes are stored
temporarily. To save them back to your system source directory, follow the
appropriate steps below:

1. After `make menuconfig`:

    Run `make savedefconfig` to update the `nerves_defconfig` in your System.

2. After `make linux-menuconfig`:

    ```bash
    make linux-savedefconfig
    cp build/linux-x.y.z/defconfig <your system>/linux-x.y_defconfig
    ```

    If your system doesn't contain a custom Linux configuration yet, you'll need
    to update the Buildroot configuration (using `make menuconfig`) to point to
    the new Linux defconfig in your system directory. The path is usually
    something like `$(NERVES_DEFCONFIG_DIR)/linux-x.y_defconfig`.

3. After `make busybox-menuconfig`:

    ```bash
    make busybox-savedefconfig
    cp build/busybox-x.y.z/defconfig <your system>/busybox-x.y_defconfig
    ```

    Like the Linux configuration, the Buildroot configuration will need to be
    updated to point to the custom config if it isn't already.

The [Buildroot user manual](http://nightly.buildroot.org/manual.html) can be
very helpful, especially if you need to add a package. The various Nerves system
repositories have examples of many common use cases, so check them out as well.
