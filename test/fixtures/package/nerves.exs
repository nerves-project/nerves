use Mix.Config

version =
  Path.join(__DIR__, "VERSION")
  |> File.read!
  |> String.trim

config :package, :nerves_env,
  type: :package,
  version: version,
  platform: Nerves.System.BR,
  platform_config: [
    defconfig: "nerves_defconfig",
    package_files: [
      "linux_defconfig"
    ]
  ]
