defmodule System.Fixture.Mixfile do
  use Mix.Project

  @version Path.join(__DIR__, "VERSION")
           |> File.read!
           |> String.trim

  def project do
    [
      app: :system,
      version: @version,
      compilers: Mix.compilers ++ [:nerves_package],
      nerves_package: nerves_package(),
      deps: deps()
    ]
  end

  defp nerves_package do
    [
      type: :system,
      platform: SystemPlatform.Fixture,
      platform_config: [
        defconfig: "nerves_defconfig",
      ],
      checksum: package_files()
    ]
  end

  defp deps do
    [
      {:nerves, path: "../../../"},
      {:toolchain, path: "../toolchain"},
      {:system_platform, path: "../system_platform"}
    ]
  end

  defp package_files do
    [
      "mix.exs",
      "nerves_defconfig",
      "VERSION"
    ]
  end
end
