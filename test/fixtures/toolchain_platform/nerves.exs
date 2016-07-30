use Mix.Config

version =
  Path.join(__DIR__, "VERSION")
  |> File.read!
  |> String.strip

config :toolchain_platform, :nerves_env,
  type: :toolchain_platform,
  version: version,
  platform_config: [
    package_files: [
      "env.exs",
      "lib"
    ]
  ]
