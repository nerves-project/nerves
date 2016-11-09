use Mix.Config

version =
  Path.join(__DIR__, "VERSION")
  |> File.read!
  |> String.strip

config :toolchain, :nerves_env,
  type: :toolchain,
  version: version,
  compiler: :nerves_package,
  target_tuple: :x86_64_unknown_linux_musl,
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
