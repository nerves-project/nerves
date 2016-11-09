use Mix.Config

version =
  Path.join(__DIR__, "VERSION")
  |> File.read!
  |> String.strip

config :system, :nerves_env,
  type: :system,
  version: version,
  compiler: :nerves_package,
  platform: SystemPlatform.Fixture,
  platform_config: [
    defconfig: "nerves_defconfig",
  ],
  checksum: [
    "nerves_defconfig",
    "linux_defconfig"
  ]
