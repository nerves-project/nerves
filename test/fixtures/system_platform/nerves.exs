use Mix.Config

version =
  Path.join(__DIR__, "VERSION")
  |> File.read!
  |> String.trim

config :system_platform, :nerves_env,
  type: :system_platform,
  version: version,
  checksum: [
    "env.exs",
    "lib"
  ]
