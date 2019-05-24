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

    ```elixir
    defp nerves_package do
      [
        # ...
        build_runner_opts: [make_args: ["PARALLEL_JOBS=8"]],
      ]
    end
    ```

7. `checksum`: The list of files for which checksums are calculated and stored
    in the artifact cache.

    This checksum is used to match the cached Nerves artifact on disk with its
    source files, so that it will be re-compiled instead of using the cache if
    the source files no longer match.

## Customizing Your Own Nerves System

[This document has been moved](https://hexdocs.pm/nerves/customizing-systems.html)
