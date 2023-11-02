# Updating Projects

Please review this guide before updating your projects. Help is available via
the #nerves channel on the elixir-lang discord and the Elixir forum. Please file
bugs on GitHub.

Contents:

* [Updating from v0.8 to v0.9](#updating-from-v0-8-to-v0-9)
* [Updating from v0.9 to v1.0.0-rc.0](#updating-from-v0-9-to-v1-0-0-rc-0)
* [Updating from v1.0.0-rc.0 to v1.0.0-rc.2](#updating-from-v1-0-0-rc-0-to-v1-0-0-rc-2)
* [Updating from v1.0 to v1.3](#updating-from-v1-0-to-v1-3)
* [Updating from v1.3 to v1.4](#updating-from-v1-3-to-v1-4)
* [Updating from v1.4 to v1.5](#updating-from-v1-4-to-v1-5)
* [Updating from v1.5 to v1.6](#updating-from-v1-5-to-v1-6)
* [Updating from v1.6 to v1.7](#updating-from-v1-6-to-v1-7)

## Updating from v0.8 to v0.9

Nerves v0.9.0 contains changes that require updates to existing projects. All
users are highly encouraged to update, but if you cannot, be sure to force the
Nerves version in your `mix.exs` dependencies.

### Update Nerves Bootstrap to v0.8.1

Nerves Bootstrap is an Elixir archive that provides a new project generator and
some logic required for the Nerves integration into `mix`. Nerves v0.9 requires
updates to this archive.

Install the latest Nerves Bootstrap archive by running:

```bash
mix local.nerves
```

or

```bash
mix archive.install hex nerves_bootstrap
```

### Update mix.exs aliases (old)

IMPORTANT: If you're upgrading to Nerves v1.0, this step has been superseded.

Nerves requires that you add aliases to your project's `mix.exs` to pull in the
firmware creation and compilation logic. Previously, you needed to know
which aliases to override. Nerves v0.9 added a new alias. Rather than add this
alias, we recommend using the new alias helper in your `mix.exs`. To do this,
edit the target aliases function to look like this:

```elixir
defp aliases(_target) do
  [
    # Add custom mix aliases here
  ]
  |> Nerves.Bootstrap.add_aliases()
end
```

This only works with `nerves_bootstrap` v0.7.0 and later, so if you get an
error, be sure to update your Nerves Bootstrap as described in the previous
section.

For those interested in more details, the reason behind this change was to move
precompiled artifact downloads from the `mix compile` step to the `mix deps.get`
step. That entailed adding additional logic to the `deps.get` step and hence an
additional alias.

### Replace Bootloader with Shoehorn

During this release, we renamed one of our dependencies from `bootloader` to
`shoehorn` to prevent overloading the term bootloader in the embedded space.
This requires a few updates:

First, update the dependency by changing:

```elixir
{:bootloader, "~> 0.1"}
```

to

```elixir
{:shoehorn, "~> 0.2"}
```

Next, update the distillery release config in `rel/config.exs`. Look for the
line near the end that looks like:

```elixir
plugin Bootloader.Plugin
```

or

```elixir
plugin Bootloader
```

and change it to

```elixir
plugin Shoehorn
```

Finally, change references to `bootloader` in your `config/config.exs` to
`shoehorn`. For example, change:

```elixir
config :bootloader,
  init: [:nerves_runtime],
  app: :my_app
```

to

```elixir
config :shoehorn,
  init: [:nerves_runtime],
  app: :my_app
```

### Artifact checksums

Some Nerves dependencies reference a large precompiled version of their build
products to significantly reduce compilation time. These are called artifacts
and due to their size, they cannot be hosted on hex.pm. Nerves downloads these
automatically as part of the dependency resolution process. It is critical that
they match the corresponding source code and the previous method of checking
version numbers was insufficient. Nerves v0.9.0 now uses a checksum of the
projects source files. This works for all projects no matter what version
control system they use or how they are stored.

If you have created a custom Nerves system or toolchain, you will need to update
your project's `mix.exs` to ensure that the checksum covers the right files.
This is done using the `:checksum` key on the `nerves_package`. Since the files
that you checksum are likely identical to those published on hex.pm, we
recommend creating a `package_files/0` function that's used by both.

Here's an example from `nerves-project/nerves_system_rpi0`:

```elixir
  def nerves_package do
    [
      # ... Other Options
      checksum: package_files()
    ]
  end

  defp package do
    [
      files: package_files(),
      licenses: ["Apache 2.0"],
      links: %{"Github" => "https://github.com/nerves-project/#{@app}"}
    ]
  end

  defp package_files do
    [
      "LICENSE",
      "mix.exs",
      "nerves_defconfig",
      "README.md",
      "VERSION",
      "rootfs_overlay",
      "fwup.conf",
      "fwup-revert.conf",
      "post-createfs.sh",
      "post-build.sh",
      "cmdline.txt",
      "linux-4.4.defconfig",
      "config.txt"
    ]
  end
```

### Easier artifact creation

Prior to Nerves v0.9.0, creating artifacts for Nerves systems and toolchains
required manual steps. Nerves v0.9.0 adds the `nerves.artifact` mix task to make
this easier. Please update your CI scripts or build instructions to use this new
method.

Nerves makes it easier to predigest artifacts for systems and toolchains
with the added mix task `mix nerves.artifact <app_name>`. Omitting `<app_name>`
will default to the app name of the parent mix project. This is useful if
you are calling `mix nerves.artifact` from within a custom system or toolchain
project.

For example, lets say we have a custom `rpi0` system and we would like to
create an artifact. `mix nerves.artifact custom_system_rpi0`

This will produce a file in the current working directory with a name of the format
`<app_name>-<host_tuple | portable>-<version>-<checksum><extension>`

For example,
`custom_system_rpi0-portable-0.11.0-17C58821DE265AC241F28A0A722DB25C447A7B5FFF5648E4D0B99EF72EB3341F.tar.gz`

### Artifact sites

Once you've created the artifact (or had CI create it for you),
you can then upload this to Github releases and instruct the artifact resolver
to fetch this artifact following `deps.get`. Update the Nerves package config
by editing the `:nerves_package` options of `Mix.project/0` for your custom
system or toolchain to set the sites for which the artifact is available on.

This can be passed as
`{:github_releases, "<organization>/<repository>"}`
or specified as url / path prefixes
`{:prefix, "/path/to/artifact_dir"}`
`{:prefix, http://artifact_server.com/artifacts}`

```elixir
def nerves_package do
  [
    # ... Other Options
    artifact_sites: [
      {:github_releases, "nerves-project/custom_system_rpi0"}
    ]
  ]
end
```

The artifact resolver will attempt to fetch from each site listed until it
successfully retrieves an artifact or it reaches the end of the list.

## Updating from v0.9 to v1.0.0-rc.0

### Update to Nerves Bootstrap v1.0.0-rc.0

Nerves Bootstrap is an Elixir archive that provides a new project generator and
some logic required for the Nerves integration into `mix`. Nerves v1.0-rc
requires updates to this archive.

Install the latest Nerves Bootstrap archive by running:

```bash
mix local.nerves
```

or

```bash
mix archive.install hex nerves_bootstrap
```

### Update project dependencies

You will need to update the version string for `nerves` and `nerves_bootstrap`
in your projects to enable the usage of `1.0-rc`. Open your `mix.exs` file and
start by updating the `nerves_bootstrap` archive:

```elixir
  # mix.exs

  def project do
    [
      # ...
      archives: [{:nerves_bootstrap, "~> 1.0-rc"}],
    ]
  end
  ```

Then update the nerves dep:

```elixir

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [{:nerves, "~> 1.0-rc", runtime: false}] ++ deps(@target)
  end

```

You may have to set `override: true` if you are using other Nerves packages that
have not been updated to depend on Nerves 1.0-rc yet

If you wish to revert, you lock to a specific version using `~> 0.8.0` or `= 0.8.0`

### Update mix.exs aliases

`nerves_bootstrap` 1.0-rc manages its own aliases on `Application.start/1` and
is invoked by setting `MIX_TARGET` to value other then `host`. Update your
`mix.exs` file to add the `bootstrap/1` function and change the aliases to
`[loadconfig: [&bootstrap/1]]`:

```elixir

  # mix.exs

  def project do
    [
      # ...
      aliases: [loadconfig: [&bootstrap/1]],
    ]
  end

  # Starting nerves_bootstrap pulls in the Nerves hooks to mix, but only
  # if the MIX_TARGET environment variable is set.
  defp bootstrap(args) do
    Application.start(:nerves_bootstrap)
    Mix.Task.run("loadconfig", args)
  end

```

## Updating from v1.0.0-rc.0 to v1.0.0-rc.2

### Updating Provider to BuildRunner

**This only applies to custom systems and host tools**

Nerves v1.0.0-rc.2 renames the module `Nerves.Artifact.Provider` to
`Nerves.Artifact.BuildRunner`.

The `nerves_package` config allowed the package to override
`provider` and `provider_opts`. These keys have been renamed to
`build_runner` and `build_runner_opts`

For example:

```elixir
  def nerves_package do
    [
      # ..
      build_runner: Nerves.Artifact.BuildRunner.Docker,
      # ..
    ]
  end
```

## Updating from v1.0 to v1.3

### Modify the release config

Nerves now runs as a distillery plugin instead of inside the `rel/config.exs`.

You will need to change your `rel/config.exs`. Find the section near the bottom
of the file that defines your application.

Change this:

```elixir
release :my_app do
  set version: current_version(:my_app)
  plugin Shoehorn
  if System.get_env("NERVES_SYSTEM") do
    set dev_mode: false
    set include_src: false
    set include_erts: System.get_env("ERL_LIB_DIR")
    set include_system_libs: System.get_env("ERL_SYSTEM_LIB_DIR")
    set vm_args: "rel/vm.args"
  end
end
```

To this:

```elixir
release :my_app do
  set version: current_version(:my_app)
  plugin Shoehorn
  plugin Nerves
end
```

### Update shoehorn dependency

You will need to update your version of shoehorn to `{:shoehorn, "~> 0.4"}`.

## Updating from v1.3 to v1.4

Version v1.4.0 adds support for Elixir 1.8's new built-in support for mix
targets. In Nerves, the `MIX_TARGET` was used to select the appropriate set of
dependencies for a device. This lets you switch between building for different
boards and your host. Elixir 1.8 pulls this support into `mix` and lets you
annotate dependencies for which targets they should be used.

### Update your mix.exs file

The `@target` is no longer used. Delete it and then add `@all_targets` like this:

```elixir
@target System.get_env("MIX_TARGET") || "host"
```

```elixir
@all_targets [:rpi0, :rpi3, :rpi]
```

The `@all_targets` alias will be convenient when updating the dependencies in
your `mix.exs`. Set it to the target names that you use (in atom form). Like the
previous use of `MIX_TARGET`, it didn't matter what you called the targets. It
only mattered that you were consistent.

The `:host` target refers to compilation for your computer. It's the only
special target and is used for running non-hardware-specific unit tests.

Next, remove the following lines from the `project/0` callback (yay Elixir 1.8):

```elixir
  target: @target
  deps_path: "deps/#{@target}"
  build_path: "_build/#{@target}"
  lockfile: "mix.lock.#{@target}"
```

Change `build_embedded` from

```elixir
build_embedded: @target != "host"
```

to

```elixir
build_embedded: Mix.target() != :host,
```

The next step is to consolidate your dependencies to one `deps/0` function.
Nerves previously grouped dependencies and used pattern matches to pick the
right ones for your device. Elixir 1.8 makes this unnecessary.

Now Elixir can fetch and lock your dependencies for all targets. Previously, if
you'd switch targets, your dependencies might change versions. No more!

Elixir 1.8 adds the `:targets` option on dependencies. Here's an example:

Before:

```elixir
  # Run "mix help deps" to learn about dependencies.
  # Dependencies for all targets
  defp deps do
    [
      {:nerves, "~> 1.3", runtime: false},
      {:shoehorn, "~> 0.4"},
      {:ring_logger, "~> 0.6"},
      {:toolshed, "~> 0.2"}
    ] ++ deps(@target)
  end

  # Specify target specific dependencies
  defp deps("host"), do: []

  # Dependencies for all targets except :host
  defp deps(target) do
    [
      {:nerves_runtime, "~> 0.6"},
      {:nerves_init_gadget, "~> 0.4"}
    ] ++ system(target)
  end

  # Dependencies for specific targets
  defp system("rpi"), do: [{:nerves_system_rpi, "~> 1.5", runtime: false}]
  defp system("rpi0"), do: [{:nerves_system_rpi0, "~> 1.5", runtime: false}]
  defp system("rpi2"), do: [{:nerves_system_rpi2, "~> 1.5", runtime: false}]
  defp system("rpi3"), do: [{:nerves_system_rpi3, "~> 1.5", runtime: false}]
  defp system("bbb"), do: [{:nerves_system_bbb, "~> 2.0", runtime: false}]
  defp system("x86_64"), do: [{:nerves_system_x86_64, "~> 1.5", runtime: false}]
  defp system(target), do: Mix.raise("Unknown MIX_TARGET: #{target}")
```

After:

```elixir
  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Dependencies for all targets
      {:nerves, "~> 1.4", runtime: false},
      {:shoehorn, "~> 0.4"},
      {:ring_logger, "~> 0.6"},
      {:toolshed, "~> 0.2"},

      # Dependencies for all targets except :host
      {:nerves_runtime, "~> 0.6", targets: @all_targets},

      # Dependencies for specific targets
      {:nerves_system_rpi, "~> 1.5", runtime: false, targets: :rpi},
      {:nerves_system_rpi0, "~> 1.5", runtime: false, targets: :rpi0},
      {:nerves_system_rpi2, "~> 1.5", runtime: false, targets: :rpi2},
      {:nerves_system_rpi3, "~> 1.5", runtime: false, targets: :rpi3},
      {:nerves_system_rpi3a, "~> 1.5", runtime: false, targets: :rpi3a},
      {:nerves_system_bbb, "~> 2.0", runtime: false, targets: :bbb},
      {:nerves_system_x86_64, "~> 1.5", runtime: false, targets: :x86_64}
    ]
  end
```

### Update config.exs

Accessing the `MIX_TARGET` is done differently now. References in your
`config.exs` to `Mix.Project.config[:target]` need to be `Mix.target()` now. For
example, change this:

```elixir
import_config "#{Mix.Project.config[:target]}.exs
```

to:

```elixir
import_config "#{Mix.target()}.exs"
```

### Update application.ex

Search your Elixir code for references to `Mix.Project.config()[:target]`. These
need to change as well. It's not uncommon to have these in your `application.ex`
to decide what to start in your main supervision tree. For example, change this:

```elixir
@target Mix.Project.config()[:target]
```

to:

```elixir
@target Mix.target()
```

## Updating from v1.4 to v1.5

Nerves v1.5 adds support for [Elixir 1.9+
releases](https://elixir-lang.org/blog/2019/06/24/elixir-v1-9-0-released/).
Previous versions of Nerves only supported
[Distillery](https://github.com/bitwalker/distillery) for OTP release creation.
Nerves v1.5 still supports Distillery, but it is no longer included by default.
Nerves v1.5 also still supports previous Elixir versions, so there is no need to
update to Elixir 1.9.

The most important part of the Nerves v1.5 upgrade process is to make sure that
Nerves knows whether you want to use Elixir 1.9 releases or Distillery. Please
find the subsections below that correspond to your environment.

### Update nerves_bootstrap

Nerves now requires `nerves_bootstrap` 1.5.1 and later. Assuming that you
already have it installed, run:

```bash
mix local.nerves
```

`nerves_bootstrap` v1.6.0 and later generate Elixir 1.9-based projects. This
functionality does not affect existing projects if you are not updating your
Elixir version. However, if you cannot update Elixir and still want to create
new projects, force the `nerves_bootstrap` installation to `~> 1.5.0`:

```bash
mix archive.install hex nerves_bootstrap "~> 1.5.0"
```

### Update Elixir < 1.9.0 projects

If you're not updating to Elixir 1.9, then Distillery is your only option for
OTP release creation and must be explicitly specified. The following steps will
ensure that your project has the appropriate updates:

In your `mix.exs`, add distillery as a dependency of your project:

```elixir
{:distillery, "~> 2.1"}
```

Distillery 2.1 moved code out of the `Mix.Releases` namespace. This requires a
change to your project's `rel/config.exs`. Open `rel/config.exs` and look for
the following line:

```elixir
use Mix.Releases.Config
```

Change it to:

```elixir
use Distillery.Releases.Config
```

Finally, check that the `:shoehorn` dependency is `~> 0.6`:

```elixir
{:shoehorn, "~> 0.6"}
```

Run `mix deps.get` and your project should continue to work.

At this point, consider updating your Nerves system to the latest to pull in
Linux, Erlang, and other C library and application updates.

### Update Elixir ~> 1.9

First verify that you have `nerves_bootstrap` 1.6.0 or later installed:

```bash
$ mix archive
* hex-0.20.1
* nerves_bootstrap-1.6.0
```

The following instructions are for updating your project files to use Elixir 1.9
releases. If you must use Distillery, see the instructions above for Elixir `<
1.9.0` projects.

#### mix.exs updates

In your project's `mix.exs`, make the following edits:

1. Move the application name to a module attribute:

    ```elixir
    @app :my_app

    def project do
      [
        app: @app
        # ...
      ]
    end
    ```

2. Add release config to the project config:

    ```elixir

    def project do
      [
        # ...
        releases: [{@app, release()}]
      ]
    end

    def release do
      [
        overwrite: true,
        cookie: "#{@app}_cookie",
        include_erts: &Nerves.Release.erts/0,
        steps: [&Nerves.Release.init/1, :assemble],
        strip_beams: Mix.env() == :prod
      ]
    end
    ```

3. Update the nerves and shoehorn dependencies

    ```elixir
    def deps
      [
        {:nerves, "~> 1.5.0", runtime: false},
        {:shoehorn, "~> 0.6"},
        # ...
      ]
    end
    ```

4. Update the required archives:

    ```elixir
    def project do
      [
        # ...
        archives: [nerves_bootstrap: "~> 1.6"],
      ]
    end
    ```

5. Add preferred CLI target to the project config:

    ```elixir
    def project do
      [
        # ...
        preferred_cli_target: [run: :host, test: :host]
      ]
    end
    ```

#### vm.args updates

Next, rename `rel/vm.args` to `rel/vm.args.eex`

Then update the line that sets the cookie to

```elixir
-setcookie <%= @release.options[:cookie] %>
```

#### Erase old Distillery files

Since Distillery is no longer being used, erase any Distillery configuration
files that are still around. For most Nerves users, run the following:

```bash
rm rel/config.exs
rm rel/plugins/.gitignore
```

#### Nerves system update

Elixir 1.9+ releases are only compatible with systems that contain [`erlinit ~>
1.5`](https://github.com/nerves-project/erlinit/releases/tag/v1.5.0).

If you are using an official Nerves system, then make sure that you are using
one of these versions:

```text
nerves_system_rpi:    ~> 1.8
nerves_system_rpi2:   ~> 1.8
nerves_system_rpi3:   ~> 1.8
nerves_system_rpi3a:  ~> 1.8
nerves_system_rpi0:   ~> 1.8
nerves_system_x86_64: ~> 1.8
nerves_system_bbb:    ~> 2.3
```

If you are using a custom system, you will need to update `nerves_system_br` to
 a version that is >= `1.8.1`.

#### config.exs updates

Nerves has been improving support for "host" builds of firmware projects. This
makes it possible to unit test platform-independent code on your build machine.
To take advantage of this, it's important to separate out the target-dependent
sections of the `config.exs`. Here's one way of doing this:

1. Create a new file `config/target.exs`

2. Move configs for applications that are only available on the target to the
`target.exs` file.

3. Update `config.exs` to import `target.exs` if the target is not `host`.

    ```elixir
    if Mix.target() != :host do
      import_config "target.exs"
    end
    ```

## Updating from v1.5 to v1.6

Nerves 1.6 adds support for Elixir 1.10. In truth, only the internals of the
Nerves tooling were changed. As a result of this change, we made the decision to
drop support for Elixir 1.6 and Erlang 20. If you are still using these older
versions, you'll need to update to at least Elixir 1.7 and Erlang 21. Then
update to Nerves 1.6.

To update your projects to use Nerves 1.6, bump the `:nerves` dependency in your
project's `mix.exs`:

```elixir
  defp deps do
    [
      ...
      {:nerves, "~> 1.6.0", runtime: false},
      ...
    ]
  end
```

Run `mix deps.get` and build as normal. You may also need to update your Nerves
system to a newer official build. Many systems have dependency requirements on
Nerves 1.5 that can be updated to Nerves 1.6 without issue. Please review the
Nerves system release notes when you upgrade.

## Updating from v1.6 to v1.7

The only backwards incompatible change in Nerves 1.7 is to remove Distillery
support. See [Updating from v1.4 to v1.5](#updating-from-v1-4-to-v1-5) for how
to move to mix releases.
