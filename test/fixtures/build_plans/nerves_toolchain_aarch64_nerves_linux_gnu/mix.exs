defmodule NervesToolchainAarch64NervesLinuxGnu.MixProject do
  use Mix.Project

  @app :nerves_toolchain_aarch64_nerves_linux_gnu
  @version Path.join(__DIR__, "VERSION")
           |> File.read!()
           |> String.trim()
  @description "Nerves Toolchain - aarch64-nerves-linux-gnu"
  @source_url "https://github.com/nerves-project/toolchains"

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.13",
      description: @description,
      package: package(),
      source_url: @source_url,
      nerves_package: nerves_package(),
      deps: deps(),
      docs: docs()
    ]
  end

  def application do
    []
  end

  def cli do
    [preferred_envs: %{docs: :docs, "hex.publish": :docs, "hex.build": :docs}]
  end

  defp nerves_package do
    [
      type: :toolchain,
      platform: NervesToolchainAarch64NervesLinuxGnu,
      target_tuple: :aarch64_nerves_linux_gnu,
      artifact_sites: [
        {:github_releases, "nerves-project/toolchains"}
      ],
      checksum: checksum_files()
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.22", only: :docs, runtime: false},
      {:nerves, "~> 1.13", runtime: false}
    ]
  end

  defp package do
    [
      files: package_files(),
      licenses: [
        "GPL-3.0-or-later",
        "GPL-2.0-only",
        "LGPL-2.1-or-later",
        "MIT",
        "LGPL-3.0-or-later",
        "Zlib"
      ],
      links: %{
        "Github" => "https://github.com/nerves-project/toolchains/tree/main/#{@app}"
      }
    ]
  end

  defp docs do
    [
      extras: ["README.md"],
      main: "readme"
    ]
  end

  defp package_files do
    [
      "README.md",
      "LICENSE",
      "lib",
      "mix.exs",
      "scripts",
      "VERSION"
    ] ++ checksum_files()
  end

  # These files contribute to the short checksum that gets included in the
  # artifact name to reduce mix ups caused by configs changing without
  # rebuilding. Include anything that meaningfully contributes to the toolchain.
  # Docs and Elixir don't normally contributed to the crosstool-ng builds.
  defp checksum_files do
    [
      "defconfig",
      "build.sh",
      "patches",
      "defaults"
    ]
  end
end
