defmodule ToolchainPlatform.Fixture.Mixfile do
  use Mix.Project

  @version Path.join(__DIR__, "VERSION")
    |> File.read!
    |> String.trim

  def project do
    [
      app: :toolchain_platform,
      version: @version,
      nerves_package: nerves_package(),
      deps: deps()
    ]
  end

  defp nerves_package do
    [
      type: :toolchain_platform,
      checksum: package_files()
    ]
  end

  defp deps do
    []
  end

  defp package_files do
    [
      "mix.exs",
      "env.exs",
      "lib",
      "VERSION"
    ]
  end
end
