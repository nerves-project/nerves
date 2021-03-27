defmodule HostTool.MixProject do
  use Mix.Project

  def project do
    [
      app: :host_tool,
      version: "0.1.0",
      elixir: "~> 1.5",
      compilers: Mix.compilers() ++ [:nerves_package],
      nerves_package: nerves_package(),
      aliases: Nerves.Bootstrap.add_aliases([]),
      xref: [
        exclude: [
          Nerves.Artifact,
          Nerves.Artifact.Cache,
          Nerves.Package.Platform,
          Nerves.Port,
          Nerves.Utils.File
        ]
      ]
    ]
  end

  defp nerves_package do
    [
      type: :host_tool,
      platform: HostTool.Platform,
      platform_config: [],
      checksum: package_files()
    ]
  end

  defp package_files do
    [
      "lib",
      "mix.exs",
      "VERSION",
      "Makefile",
      "c_src"
    ]
  end
end
