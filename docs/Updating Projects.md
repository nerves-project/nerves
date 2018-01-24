# Updating from v0.8 to v0.9

Nerves v0.9.0 Introduces changes that will require existing projects to make 
modifications.

## Updating Nerves Bootstrap

Install the latest `nerves_bootstrap` but calling `mix local.nerves` or
`mix archive.install hex nerves_bootstrap`. 

## Updating aliases

Starting in v0.9 Nerves will no longer attempt to fetch precompiled artifacts
from the network during `mix compile`. Artifacts are expected to be resolved 
following `mix deps.get`. `nerves_bootstrap` v0.7.0 adds an alias helper for 
adding the required Nerves aliases.

To use the new alias helper, edit the target aliases in your `mix.exs` file

```elixir
defp aliases(_target) do
  [
    # Add custom mix aliases here
  ]
  |> Nerves.Bootstrap.add_aliases()
end
```

Nerves will add the aliase it requires to any aliases you pass to 
`Nerves.Bootstrap.add_aliases/1` and ensure they are in the correct order.

## Replacing Bootloader with Shoehorn

During this release, we renamed one of our dependencies from `bootloader` to
`shoehorn` to prevent overloading the term bootloader in the embedded space.

First, lets update the dependency. 

Change

```elixir
{:bootloader, "~> 0.1"}
```

to

```elixir
{:shoehorn, "~> 0.2"}
```

Next, lets update the distillery release config in `rel/config.exs`

Find the line near the end that has

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

Finally, In your `config/config.exs`

Change:
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

## Artifact checksums

Artifact checksums are used as a basis for associating system and toolchain source
to artifacts. They are used to determine if the `nerves_package` is invoked and in 
naming and resolving artifacts from sites. The checksum configured by passing
a list of files and directories to the `checksum` key in the `nerves_package`
config. Typically the value of this list is the same as the `files` for
hex.pm. Therefore, it is recommended that you create a `package_files/0` method
in your mix file that contains all the files and directories required to build 
your system or toolchain that you can reference for both Nerves checksum and 
hex files.

For example, here is a snippet from `nerves-project/nerves_system_rpi0`

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

## Artifact files

Nerves makes it easier to predigest artifacts for systems and toolchains by
with the added mix task `mix nerves.artifact <app_name>` where app_name is the
name of system or toolchain depndency to make an artifact for. Ommitting `<app_name>`
will default to the app name of the parent mix project. This is useful if
you are calling `mix nerves.artifact` from within a custom system or toolchain
project.

For example, lets say we have a custom `rpi0` system and we would like to
create an artifact. `mix nerves.artifact custom_system_rpi0`

This will produce a file in the current working directory with a name of the format
`<app_name>-<host_tuple | portable>-<version>-<checksum><extension>`

For example, 
`custom_system_rpi0-portable-0.11.0-17C58821DE265AC241F28A0A722DB25C447A7B5FFF5648E4D0B99EF72EB3341F.tar.gz`

## Artifact sites

You can then upload this to Github releases and instruct the artifact resolver
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
