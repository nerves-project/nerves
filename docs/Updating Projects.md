# Updating Projects

Please review this guide before updating your projects. Help is available via
the #nerves channel on the elixir-lang slack and the Elixir forum.

Contents:

* [Updating from v0.8 to v0.9](#updating-from-v08-to-v09)
* [Updating from v0.9 to v1.0.0-rc.0](#updating-from-v09-to-v100-rc0)

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

IMPORTANT: If you're upgrading to Nerves v1.0, this step has been superceded.

Nerves requires that you add aliases to your project's `mix.exs` to pull in the
firmware creation and crosscompilation logic. Previously, you needed to know
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
they match the corresponding source code and the previous method of checking version numbers was insufficient. Nerves v0.9.0 now uses a checksum of the projects source files. This works for all projects no matter what version control system they use or how they are stored.

If you have created a custom Nerves system or toolchain, you will need to update your project's `mix.exs` to ensure that the checksum covers the right files. This is done using the `:checksum` key on the `nerves_package`. Since the files that you checksum are likely identical to those published on hex.pm, we recommend creating a `package_files/0` function that's used by both.

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
      maintainers: ["Timothy Mecklem", "Frank Hunleth"],
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
with the added mix task `mix nerves.artifact <app_name>` Ommitting `<app_name>`
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
`{:github_releases, "<orginization>/<repository>"}`
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
successfully retreives an artifact or it reaches the end of the list.

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
