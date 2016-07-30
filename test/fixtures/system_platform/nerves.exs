use Mix.Config

version =
  Path.join(__DIR__, "VERSION")
  |> File.read!
  |> String.strip

config :system_platform, :nerves_env,
  type: :system_platform,
  version: version,
  platform_config: [
    package_files: [
      "env.exs",
      "lib"
    ]
  ]
