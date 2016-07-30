use Mix.Config

version =
  Path.join(__DIR__, "VERSION")
  |> File.read!
  |> String.strip

config :system, :nerves_env,
  type: :system,
  version: version,
  platform: SystemPlatform.Fixture,
  platform_config: [
    defconfig: "nerves_defconfig",
    package_files: [
      "linux_defconfig"
    ]
  ]
