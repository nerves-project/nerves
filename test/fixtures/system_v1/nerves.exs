use Mix.Config

version =
  Path.join(__DIR__, "VERSION")
  |> File.read!
  |> String.strip

config :system_v1, :nerves_env,
  type: :system,
  platform: SystemPlatform.Fixture,
  platform_config: [
    defconfig: "nerves_defconfig"
  ]
