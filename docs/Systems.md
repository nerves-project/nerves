# Systems

## Using a Nerves System

When you generate a new Nerves project using the `mix nerves.new` task, you will
end up with something like the following in your `mix.exs` configuration:

```elixir
  # ...
  @target System.get_env("MIX_TARGET") || "host"
  # ...
  defp deps do
    [
      {:nerves, "~> 1.3", runtime: false},
      {:shoehorn, "~> 0.4"},
      {:ring_logger, "~> 0.4"}
    ] ++ deps(@target)
  end

  defp deps("host"), do: []

  defp deps(target) do
    [
      {:nerves_runtime, "~> 0.6"}
    ] ++ system(target)
  end

  def system("rpi"), do: {:nerves_system_rpi, "~> 1.0", runtime: false}
  def system("rpi0"), do: {:nerves_system_rpi0, "~> 1.0", runtime: false}
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
   aliases: [loadconfig: [&bootstrap/1]]]
end
# ...
def nerves_package do
  [
    type: :system,
    artifact_sites: [
      {:github_releases, "nerves-project/#{@app}",
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
    {:nerves, "~> 1.0", runtime: false},
    {:nerves_system_br, "~> 1.0", runtime: false},
    {:nerves_toolchain_arm_unknown_linux_gnueabihf, "~> 1.0", runtime: false}
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

1. The `compilers` must include `:nerves_package` compiler after `Mix.compilers`.
2. There must be a dependency for the toolchain and the build platform.
3. The `package` must specify all the required `files` so they are present when
   downloading from Hex.
4. The `nerves_package` key should contain nerves package configuration metadata as
   described in the next section.

## Nerves Package Configuration

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
defp nerves_package do
  [
    type: :system,
    artifact_sites: [
      {:github_releases, "nerves-project/#{@app}"}
    ],
    platform: Nerves.System.BR,
    platform_config: [
      defconfig: "nerves_defconfig"
    ],
    checksum: package_files()
  ]
end
```

The following keys are supported:

1. `type`: The type of Nerves Package.

    Options are: `system`, `system_compiler`, `system_platform`,
    `system_package`, `toolchain`, `toolchain_compiler`, `toolchain_platform`.

2. `artifact_sites` (optional): Artifact sites specify how to download
    artifacts. Sites are tried until one works.

    Supported artifact sites:

    ```elixir
    {:github_releases, "organization/project"}
    {:github_api, "organization/project", username: System.get_env("GITHUB_USER"), token: System.get_env("GITHUB_TOKEN"), tag: @version}
    {:prefix, "http://myserver.com/artifacts"}
    {:prefix, "file:///my_artifacts/"}
    {:prefix, "/users/my_user/artifacts/"}
    {:prefix, "http://myserver.com/artifacts", headers: [{"Authorization", "Basic 12345"}]}
    {:prefix, "http://myserver.com/artifacts", query_params: %{"id" => "1234"}}
    ```

    For official Nerves systems and toolchains, we upload the artifacts to
    GitHub Releases.

    For an artifact site that uses `:github_api` be sure to have `username`, `token`, and `tag`
    fields are set as they are required. Otherwise, you will get an exception when trying to
    download the artifact.

    Artifact sites can pass options as a third parameter for adding headers
    or query string parameters. For example, if you are trying to resolve
    artifacts hosted using `:github_releases` in a private repo,
    you can pass a personal access token into the sites helper.

    ```elixir
    {:github_releases, "my-organization/my_repository", query_params: %{"access_token" => System.get_env("GITHUB_ACCESS_TOKEN")}}
    ```

    You can also use this to add an authorization header for files behind basic auth.

    ```elixir
    {:prefix, "http://my-organization.com/", headers: [{"Authorization", "Basic " <> System.get_env("BASIC_AUTH")}}]}
    ```

3. `platform`: The build platform to use for the system or toolchain.

4. `platform_config`: Configuration options for the build platform.

    In this example, the `defconfig` option for the `Nerves.System.BR`
    platform points to the Buildroot defconfig fragment file used to build the
    system.

5. `build_runner`: Optional - The build_runner that should be used to build the artifact.

    If this key is not defined, Nerves will choose a default build_runner
    that should be used to build the artifact based on information about the host
    computer that you are building on. For example, Mac OS will use
    `Nerves.Artifact.BuildRunners.Docker` where as Linux will use
    `Nerves.Artifact.BuildRunners.Local`. Specifying a build_runner module in
    the package config could be used to force the build_runner.

6. `build_runner_opts`: Optional - A keyword list of options to pass to the build_runner module.

    `make_args:` - Extra arguments to be passed to make.

    For example:

    You can configure the number of parallel jobs that Buildroot
    can use for execution. This is useful for situations where you may
    have a machine with a lot of CPUs but not enough ram.

      # mix.exs
      defp nerves_package do
        [
          # ...
          build_runner_opts: [make_args: ["PARALLEL_JOBS=8"]],
        ]
      end

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

Make sure not to forget the `-b` flag. Cloning/Forking directly from master is not
considered stable.

```bash
git clone https://github.com/nerves-project/nerves_system_rpi3.git custom_rpi3 -b v1.7.3
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
git checkout -b master
git push origin master
```

Next, tweak the metadata for your system so it won't conflict with the official
one and won't try to download a cached artifact that doesn't exist yet:

```elixir
# custom_rpi3/mix.exs
# ...
defp nerves_package do
  [
    type: :system,
    # artifact_sites: [
    #   {:github_releases, "nerves-project/#{@app}"}
    # ],
    platform: Nerves.System.BR,
    platform_config: [
      defconfig: "nerves_defconfig"
    ],
    checksum: package_files()
  ]
end
# ...
```

```elixir
# custom_rpi3/mix.exs

# =vvv= Update the module and application names
defmodule CustomRpi3.MixProject do
  use Mix.Project

  def project do
    [
      app: @app,
      version: @version,
      # ...
    ]
  end


  # =vvv= Update project information
  defp package do
    [
      # ...
      links: %{"Github" => "https://github.com/YourGitHubUserName/custom_rpi3"}
    ]
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
  #=vvv= Update your_project/mix.exs to accept your new :custom_rpi3 target

  # ...
  @all_targets [:rpi, :rpi0, :rpi2, :rpi3, :rpi3a, :bbb, :x86_64, :custom_rpi3]
  #                                                               =^^^^^^^^^^=

  defp deps do
    [
      # Dependencies for all targets
      # ...

      # Dependencies for specific targets
      {:nerves_system_rpi, "~> 1.6", runtime: false, targets: :rpi},
      {:nerves_system_rpi0, "~> 1.6", runtime: false, targets: :rpi0},
      # ...
      {:custom_rpi3, path: "../custom_rpi3", runtime: false, targets: :custom_rpi3}
    ]
  end
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

## Buildroot Package Configuration

Because Buildroot can only be used from Linux, Nerves provides an abstraction
layer called the Nerves system configuration shell that allows the same
procedure to be used on Linux and non-Linux development hosts by using a
Linux-based Docker container on non-Linux platforms. To access this environment,
run the `mix nerves.system.shell` task from the custom system source directory.

```bash
$ mix deps.get
Mix environment
 MIX_TARGET:   custom_rpi3
 MIX_ENV:      dev

Running dependency resolution...
Dependency resolution completed:
# <-SNIP->
* Getting nerves (Hex package)
 Checking package (https://repo.hex.pm/tarballs/nerves-1.3.0.tar)
# <-SNIP->

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

    Once done with configuring the kernel, you can save the Linux config to the
    default configuration file using `make linux-update-defconfig`. The destination
    file is `linux-4.9.defconfig` in your project's root (or whatever the kernel
    version is you're working with).

    > NOTE: If your system doesn't contain a custom Linux configuration yet,
    you'll need to update the Buildroot configuration (using `make menuconfig`)
    to point to the new Linux defconfig in your system directory. The path is
    usually something like `$(NERVES_DEFCONFIG_DIR)/linux-x.y_defconfig`.

3. After `make busybox-menuconfig`:

    Unfortunately, there's not currently an easy way to save a BusyBox defconfig.
    What you have to do instead is save the full BusyBox config and configure it
    to be included in your `nerves_defconfig`.

    Assuming you're using the Nerves System Shell via Docker on a non-Linux host
    and your custom system source directory is called `custom_rpi3`, you'll need
    to do something like the following (the version identifiers might be
    different for you).

    ```bash
    cp build/busybox-1.27.2/.config /nerves/env/custom_rpi3/busybox_defconfig
    ```

    Like the Linux configuration, the Buildroot configuration will need to be
    updated to point to the custom config if it isn't already. This can be done
    via `make menuconfig` and navigating to **Target Packages** and finding the
    **Additional BusyBox configuration fragment files** option under the
    **BusyBox** package, which should already be enabled and already have a base
    configuration specified. If you're following along with this example, the
    correct configuration value should look like this:

    ```bash
    ${NERVES_DEFCONFIG_DIR}/busybox_defconfig
    ```

The [Buildroot user manual](http://nightly.buildroot.org/manual.html) can be
very helpful, especially if you need to add a package. The various Nerves system
repositories have examples of many common use cases, so check them out as well.

## Adding a custom Buildroot Package

If you have a non-Elixir program that's too complicated to compile with
[elixir_make](https://github.com/elixir-lang/elixir_make) and not included in
Buildroot, you'll need to add instructions for how to build it to your system.
This is called a "custom Buildroot package" and the process to add one in a
Nerves System is nearly the same as in Buildroot. This is documented in the
[Adding new package](http://nightly.buildroot.org/manual.html#adding-packages)
chapter of the Buildroot manual. The main difference with Nerves is the
directory.

As you go through this process, please consider whether it makes sense to
contributor your package upstream to Buildroot.

A Nerves System will need the following files in the root of the custom system
directory:

1. `Config.in` - Includes each package's `Config.in` file
2. `external.mk` - Includes each package's `<package-name>.mk` file
3. `packages` - Directory containing your custom package directories

Each directory _inside_ the `packages` directory should contain two things:

1. `Config.in` - Defines package information
2. `<package-name>.mk` - Defines how a package is built.

So if you wanted to build a package `libfoo`, first create the `Config.in` and
`external.mk` files at the base directory of your system.

`/Config.in`:

```plain
menu "Custom Packages"

source "$NERVES_DEFCONFIG_DIR/packages/libfoo/Config.in"

endmenu
```

`/external.mk`:

```make
include $(sort $(wildcard $(NERVES_DEFCONFIG_DIR)/packages/*/*.mk))
```

Then create the package directory and package files:

```bash
mkdir -p packages/libfoo
touch packages/libfoo/Config.in
touch packages/libfoo/libfoo.mk
```

At this point you should follow the Official Buildroot documentation for what
should be added to these files. Often the easiest route is to find a similar
package in Buildroot and copy/paste the contains with appropriate renaming.

## Creating an Artifact

Building a Nerves system can require a lot of system resources and often takes a
long time to complete. Once you are satisfied with the configuration of your
Nerves system and you are ready to make a release you can create an artifact.
An artifact is a pre-compiled version of your Nerves system that can be
retrieved when calling `mix deps.get`. Artifacts will attempt to be retrieved
using one of the helpers specified in the `artifact_sites` list in
the `nerves_package` config.

There are currently three different helpers,
`{:github_releases, "organization/repo"}`,
`{:github_api, "organization/repo", username: "", token: "", tag: ""}`, and
`{:prefix, "url", opts \\ []}` . `artifact_sites` only declare the path of the location to
the artifact. This is because the name of the artifact is defined by Nerves and
used to download the correct one. The artifact name for a Nerves system follows
the structure `<name>-portable-<version>-<checksum>.tar.gz`. The checksum at
the end of the file is calculated based off the contents of the files and
directories specified in the `checksum` list in the `nerves_package` configuration.
It is important to note that if you modify contents of any of the `checksum` files
or directories after creating the artifact, the artifact will not match and will
not be used. Therefore, you first need to define the `artifact_sites` before
creating the artifact.

To construct a artifact, simply build the project and call `mix nerves.artifact`
from within the directory of your custom Nerves system. For example, if your
system name is `custom_rpi3` and the version is `0.1.0` you will see a file
similar to `custom_rpi3-portable-0.1.0-ABCDEF0.tar.gz` in your current working
directory. This file should be placed in the location specified by the
`artifact_sites`. If you are using the Github Releases helper, you will need
to create a release from your tag on Github and then upload the file.
