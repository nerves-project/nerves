defmodule PackageBuildRunnerOpts.Fixture.Mixfile do
  use Mix.Project

  @version Path.join(__DIR__, "VERSION")
           |> File.read!()
           |> String.trim()

  def project do
    [
      app: :package_build_runner_opts,
      version: @version,
      compilers: Mix.compilers() ++ [:nerves_package],
      nerves_package: nerves_package(),
      deps: deps(),
      aliases: Nerves.Bootstrap.add_aliases([])
    ]
  end

  defp nerves_package do
    [
      type: :package,
      build_runner_opts: [make_args: []],
      platform: Nerves.System.BR,
      platform_config: [
        defconfig: "nerves_defconfig"
      ],
      checksum: package_files()
    ]
  end

  defp deps do
    []
  end

  defp package_files do
    [
      "nerves_defconfig",
      "mix.exs",
      "VERSION"
    ]
  end
end
