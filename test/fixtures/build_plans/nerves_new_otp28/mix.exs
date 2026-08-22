defmodule NervesNewOtp28.MixProject do
  use Mix.Project

  @app :nerves_new_otp28
  @version "0.1.0"
  @all_targets [:rpi0]

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.17",
      archives: [nerves_bootstrap: ">= 0.0.0"],
      listeners: listeners(Mix.target(), Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [{@app, release()}]
    ]
  end

  def application do
    [
      mod: {NervesNewOtp28.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [preferred_targets: [run: :host, test: :host]]
  end

  defp deps do
    [
      {:cover_helper, path: "../../cover_helper", runtime: false},
      {:nerves, path: "../../../..", override: true, runtime: false},
      {:ring_logger, "~> 0.11.0"},
      {:toolshed, "~> 0.5.0"},

      # Allow Nerves.Runtime on host to support development, testing and CI.
      # See config/host.exs for usage.
      {:nerves_runtime, "~> 0.13.12"},

      # Dependencies for all targets except :host
      {:nerves_pack, "~> 0.7.1", targets: @all_targets},

      # Restrict to OTP 28 systems
      {:nerves_system_rpi0, "~> 2.0.0", runtime: false, targets: :rpi0}
    ]
  end

  def release do
    [
      overwrite: true,
      # Erlang distribution is not started automatically.
      # See https://nerves-pack.hexdocs.pm/readme.html#erlang-distribution
      cookie: "#{@app}_cookie",
      include_erts: &Nerves.Release.erts/0,
      steps: [&Nerves.init_release/1, :assemble],
      strip_beams: Mix.env() == :prod or [keep: ["Docs"]]
    ]
  end

  # Uncomment the following line if using Phoenix > 1.8.
  # defp listeners(:host, :dev), do: [Phoenix.CodeReloader]
  defp listeners(_, _), do: []
end
