use Mix.Config

version =
  Path.join(__DIR__, "VERSION")
  |> File.read!
  |> String.trim

config :toolchain_v1, :nerves_env,
  type: :toolchain
