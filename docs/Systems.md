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

## Compatibility

The Nerves System (`nerves_system_*`) dependency determines the OTP version
running on the target. It is possible that a recent update to the Nerves
System pulled in a new version of Erlang/OTP. If you are using an official
Nerves System, you can verify this by reviewing the chart below or
`CHANGELOG.md` file that comes with the release.

|            | bbb      | rpi      | rpi0     | rpi2     | rpi3     | rpi3a    | rpi4     | osd32mp1 | x86_64   | grisp2   |
| ---        | ---      | ---      | ---      | ---      | ---      | ---      | ---      | ---      | ---      | ---      |
| OTP 25.0   | 2.14.0   | 1.19.0   | 1.19.0   | 1.19.0   | 1.19.0   | 1.19.0   | 1.19.0   | 0.10.0   | 1.19.0   | 0.3.0    |
| OTP 24.3.2 | 2.13.4   | 1.18.4   | 1.18.4   | 1.18.4   | 1.18.4   | 1.18.4   | 1.18.4   | 0.9.4    | 1.18.4   | 0.2.3    |
| OTP 24.2.2 | 2.13.3   | 1.18.3   | 1.18.3   | 1.18.3   | 1.18.3   | 1.18.3   | 1.18.3   | 0.9.3    | 1.18.3   | 0.2.2    |
| OTP 24.2   | 2.13.2   | 1.18.2   | 1.18.2   | 1.18.2   | 1.18.2   | 1.18.2   | 1.18.2   | 0.9.2    | 1.18.2   | 0.2.0    |
| OTP 24.1.7 | 2.12.3   | 1.17.3   | 1.17.3   | 1.17.3   | 1.17.4   | 1.17.3   | 1.17.3   | 0.8.3    | 1.17.3   |          |
| OTP 24.1.4 | 2.12.2   | 1.17.2   | 1.17.2   | 1.17.2   | 1.17.3   | 1.17.2   | 1.17.2   | 0.8.2    | 1.17.2   |          |
| OTP 24.1.2 | 2.12.1   | 1.17.1   | 1.17.1   | 1.17.1   | 1.17.2   | 1.17.1   | 1.17.1   | 0.8.1    | 1.17.1   |          |
| OTP 24.1   | 2.12.0   | 1.17.0   | 1.17.0   | 1.17.0   | 1.17.1   | 1.17.0   | 1.17.0   | 0.8.0    | 1.17.0   |          |
| OTP 24.0.5 | 2.11.2   | 1.16.2   | 1.16.2   | 1.16.2   | 1.16.2   | 1.16.2   | 1.16.3   | 0.7.2    | 1.16.2   |          |
| OTP 24.0.2 | 2.11.1   | 1.16.1   | 1.16.1   | 1.16.1   | 1.16.1   | 1.16.1   | 1.16.1   | 0.7.1    | 1.16.1   |          |
| OTP 23.3.1 | 2.10.1   | 1.15.1   | 1.15.1   | 1.15.1   | 1.15.1   | 1.15.1   | 1.15.1   | 0.6.1    | 1.15.1   |          |
| OTP 23.2.7 | 2.10.0   | 1.15.0   | 1.15.0   | 1.15.0   | 1.15.0   | 1.15.0   | 1.15.0   | 0.6.0    | 1.15.0   |          |
| OTP 23.2.4 | 2.9.0    | 1.14.1   | 1.14.1   | 1.14.0   | 1.14.0   | 1.14.0   | 1.14.0   | 0.5.0    | 1.14.0   |          |

Run `mix deps` to see the Nerves System version and go to that system's
repository on https://github.com/nerves-project.

If you need to run a particular version of Erlang/OTP on your target, you can
either lock the `nerves_system_*` dependency in your `mix.exs` to an older
version. Note that this route prevents you from receiving security updates
from the official systems. The other option is to build a custom Nerves
system. See the Nerves documentation for building a custom system and then
run `make menuconfig` and look for the Erlang options.

## Anatomy of a Nerves System

Nerves system dependencies are a collection of configurations to be fed into
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

2. `artifact_sites` (optional): Artifacts for Nerves systems and toolchains are
    too large for most package managers and must be stored externally.
    Artifact sites specify how to download artifacts and are attempted in order
    until one is successfully downloaded.

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

    For an artifact site that uses GitHub Releases in a private repo, [create a
    personal access token](https://help.github.com/en/articles/creating-a-personal-access-token-for-the-command-line)
    and use `:github_api` with `username`, `token`, and `tag` options:

    ```elixir
    {:github_api, "owner/repo", username: "skroob", token: "1234567", tag: "v0.1.0"}
    ```

    Artifact sites can pass options as a third parameter for adding headers
    or query string parameters.

    ```elixir
    {:prefix, "https://my-organization.com",
      query_params: %{"id" => "1234567", "token" => "abcd"},
      headers: [{"Content-Type", "application/octet-stream"}]
    }
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

<p align="center">
Is something wrong?
<a href="https://github.com/nerves-project/nerves/edit/main/docs/Systems.md">
Edit this page on GitHub
</a>
</p>
