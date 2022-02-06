defmodule System.MixProject do
  use Mix.Project

  @version Path.join(__DIR__, "VERSION")
           |> File.read!()
           |> String.trim()

  def project do
    [
      app: :system,
      version: @version,
      compilers: Mix.compilers() ++ [:nerves_package],
      nerves_package: nerves_package(),
      deps: deps()
    ]
  end

  defp nerves_package do
    [
      type: :system,
      build_runner: Nerves.Artifact.BuildRunners.Local,
      platform: SystemPlatform,
      platform_config: [
        defconfig: "nerves_defconfig"
      ],
      env: [
        {"TARGET_CPU", "a_cpu"},
        {"TARGET_GCC_FLAGS", "--testing"}
      ],
      checksum: package_files()
    ]
  end

  defp deps do
    [
      # {:nerves, path: System.get_env("NERVES_PATH") || "../../../"},
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
