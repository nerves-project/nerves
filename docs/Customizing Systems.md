# Customizing Your Own Nerves System

Before following this guide, you should probably read about
[The Anatomy of a Nerves System](https://hexdocs.pm/nerves/systems.html)

For some applications, the pre-built Nerves Systems won't meet your needs. For
example, you may want to include additional Linux packages or run on hardware
that isn't in the list of [Nerves-supported
targets](https://hexdocs.pm/nerves/targets.html) yet. In order to make the build
process consistent across host platforms, Nerves uses a Docker container behind
the scenes to perform the build on non-Linux hosts. This makes it possible for
the steps below to apply to whatever host platform you're using for development,
as long as you have Docker for Mac or Docker for Windows installed on those
platforms.

## Getting Setup to Build a System

While you could design a system from scratch, it is easiest to copy and modify
an existing one, renaming it to distinguish it from the official release. For
example, if you're targeting a Raspberry Pi 3 board, do the following:

Make sure not to forget the `-b` flag. Cloning/Forking directly from `main` is
not considered stable.

```bash
git clone https://github.com/nerves-project/nerves_system_rpi3.git custom_rpi3 -b v1.12.0
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
git checkout -b main
git push origin main
```

Next, tweak the metadata of your Mix project by updating the following:

* The module name of the mix project at the top of the file
* the value of `@app` to `custom_rpi3`
* the value of `@github_organization` to your GitHub user name or organization

See the [Official Mix.Project](https://hexdocs.pm/mix/Mix.Project.html) document
for the structure of this file.

```elixir
# custom_rpi3/mix.exs
# =vvv= make sure to rename the module name
# defmodule NervesSystemRpi3.MixProject do
defmodule CustomRpi3.MixProject do
  use Mix.Project

  # =vvv= Rename `"nerves-project"` here to your user or ogranization name
  # @github_orgranization "nerves-project"
  @github_organization "YourGitHubUserOrOrganizationName"
  # =vvv= Rename `nerves_system_rpi3` here to `custom_rpi3`
  # @app :nerves_system_rpi3
  @app :custom_rpi3
end

# =^^^= The rest of this file remains the same
```

## Building the System

Now that the custom system directory is prepared, you just need to point to it
from your project's `mix.exs`. In this example, we assume that your
`custom_rpi3` system directory is in the same directory as your nerves firmware
project directory, like so:

```plain
~/projects
├── custom_rpi3
└── your_project
```

If you are starting a new project, you can generate it to support just one
target.  We will update `rpi3` to `custom_rpi3` next.

```bash
mix nerves.new your_project --target rpi3
```

```elixir
  #=vvv= Update your_project/mix.exs to accept your new :custom_rpi3 target

  # ...
  @all_targets [:rpi3, :custom_rpi3]
  #                    =^^^^^^^^^^=

  defp deps do
    [
      # Dependencies for all targets
      # ...

      # Dependencies for specific targets
      {:nerves_system_rpi3, "~> 1.6", runtime: false, targets: :rpi},
      {:custom_rpi3, path: "../custom_rpi3", runtime: false, targets: :custom_rpi3, nerves: [compile: true]}, # <===
    ]
  end
```

> NOTE: Including the `nerves: [compile: true]` option in your dependency will cause the system to be compiled
> automatically. If you don't want this behavior, remove this option and you will need to manually compile the
> system via the `mix compile` task before building firmware with it

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

> #### Quick searching menu {: .tip}
>
> Use `/` when in a config menu for quick search. Press the key of the number
> shown in the results to quickly jump to that option
> ![quick-search](assets/menu-search-tip.gif)

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

At this point, you should follow the Official Buildroot documentation for what
should be added to these files. Often the easiest route is to find a similar
package in Buildroot and copy/paste the contains with appropriate renaming.

## Creating an Artifact

Building a Nerves system can require a lot of system resources and often takes a
long time to complete. Once you are satisfied with the configuration of your
Nerves system and you are ready to make a release, you can create an artifact.
An artifact is a pre-compiled version of your Nerves system that can be
retrieved when calling `mix deps.get`. 

These are typically 100MB± in size which is usually over the size limit of most
package manager systems, like https://hex.pm. Because of this, you must store
your pre-compiled artifact externally and provide instructions for how to
retrieve it in the `artifacts_sites` list of the `nerves_pacakge` config.

There are currently three different artifact site helpers:

* `{:github_releases, "organization/repo"}`
* `{:github_api, "organization/repo", username: "", token: "", tag: ""}`
* `{:prefix, "url", opts \\ []}`

> #### Nerves Package Configuration {: .info}
> See [Nerves Package Configuration](Systems.md#nerves-package-configuration) doc
> for more info about artifact sites and customizing your Nerves package

`artifact_sites` only declare the path of the location to the artifact. This is
because the name of the artifact is defined by Nerves and used to download the
correct one. The artifact name for a Nerves system follows the structure
`<name>-portable-<version>-<checksum>.tar.gz`. The checksum at the end of the
file is calculated based off the contents of the files and directories
specified in the `checksum` list in the `nerves_package` configuration.  It is
important to note that if you modify contents of any of the `checksum` files or
directories after creating the artifact, the artifact will not match and will
not be used. Therefore, you first need to define the `artifact_sites` before
creating the artifact.

To construct an artifact, simply build the project and call `mix nerves.artifact`
from within the directory of your custom Nerves system. For example, if your
system name is `custom_rpi3` and the version is `0.1.0` you will see a file
similar to `custom_rpi3-portable-0.1.0-ABCDEF0.tar.gz` in your current working
directory. This file should be placed in the location specified by the
`artifact_sites`. If you are using the Github Releases helper, you will need
to create a release from your tag on Github and then upload the file.

Now, instead of using a `:path` dependency in your main project, you can use a
`:github` dependency to make it easier to share with others.

```elixir
# Update the `custom_rpi3` dep in your `deps/0` function.
{:custom_rpi3, github: "YourGitHubUserName/custom_rpi3", runtime: false, targets: :custom_rpi3}
```

You can also [publish the system package to hex](https://hex.pm/docs/publish).
You should not need to change anything in the `mix.exs` file at this point to
do so.

```plain
mix hex.publish
```

Back in your main project, update deps:

```elixir
# make sure you check the version here.
{:custom_rpi3, "~> 1.7", runtime: false, targets: :custom_rpi3}
```

## Custom System Maintenance

After customizing a Nerves System, creating artifacts, and publishing the
package, you will probably want to keep track of the latest updates to the
original system. Assuming you followed the `git` section in the [Getting
Started](#getting-setup-to-build-a-system) section, you will have a remote
called `upstream`. Check this by doing:

```plain
$ git remote -v
origin git@github.com:YourGitHubUserName/custom_rpi3.git (fetch)
origin git@github.com:YourGitHubUserName/custom_rpi3.git (push)
upstream https://github.com/nerves-project/nerves_system_rpi3.git (fetch)
upstream https://github.com/nerves-project/nerves_system_rpi3.git (push)
```

When you are ready to update your system (for example, after Nerves publishes a
new version), you can just merge the `upstream` changes in. For example, if you
started with `nerves_system_rpi3` at `v1.7.1`, when `v1.7.2` gets published,
you can do the following to upgrade your custom system:

```bash
git fetch --all
git merge upstream/main
# Solve any merge conflicts
git push origin main
```

You can also use the GitHub interface to do this:

```text
https://github.com/YourGitHubUserName/custom_rpi3/compare/main...nerves-project:main?expand=1
```

<p align="center">
Is something wrong?
<a href="https://github.com/nerves-project/nerves/edit/main/docs/Customizing%20Systems.md">
Edit this page on GitHub
</a>
</p>
