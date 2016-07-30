use Mix.Config

version =
  Path.join(__DIR__, "VERSION")
  |> File.read!
  |> String.strip

config :toolchain, :nerves_env,
  type: :toolchain,
  version: version,
  platform: Nerves.Toolchain.CTNG,
  platform_config: [
    defconfig: [
      darwin: "darwin_defconfig",
      linux: "linux_defconfig"
    ],
    package_files: [
      "linux_defconfig"
    ]
  ]
