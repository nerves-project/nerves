defmodule Toolchain.MixProject do
  use Mix.Project

  @version Path.join(__DIR__, "VERSION")
           |> File.read!()
           |> String.trim()

  def project() do
    [
      app: :toolchain,
      version: @version,
      compilers: Mix.compilers() ++ [:nerves_package],
      nerves_package: nerves_package(),
      deps: deps()
    ]
  end

  defp nerves_package() do
    [
      type: :toolchain,
      target_tuple: :x86_64_unknown_linux_musl,
      platform: ToolchainPlatform,
      platform_config: [
        defconfig: [
          darwin: "darwin_defconfig",
          linux: "linux_defconfig"
        ]
      ],
      checksum: package_files()
    ]
  end

  defp deps() do
    [
      {:nerves, path: System.get_env("NERVES_PATH") || "../../../", runtime: false},
      {:toolchain_platform, path: "../toolchain_platform", runtime: false}
    ]
  end

  defp package_files() do
    [
      "mix.exs",
      "linux_defconfig",
      "darwin_defconfig",
      "VERSION"
    ]
  end
end
