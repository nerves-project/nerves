defmodule HostTool.Mixfile do
  use Mix.Project

  def project do
    [ 
      app: :host_tool,
      version: "0.1.0",
      elixir: "~> 1.5",
      compilers: Mix.compilers() ++ [:nerves_package],
      nerves_package: nerves_package(),
      deps: deps(),
      aliases: Nerves.Bootstrap.add_aliases([])
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

  defp deps do
    [
      {:nerves, path: System.get_env("NERVES_PATH") || "../../../"}
    ]
  end

  defp package_files do
    [
      "lib",
      "mix.exs",
      "VERSION"
    ]
  end
end
