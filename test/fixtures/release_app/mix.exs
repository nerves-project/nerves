defmodule ReleaseApp.Fixture do
  use Mix.Project

  def project do
    [
      app: :release_app,
      version: "0.1.0",
      deps: deps(),
      releases: [{:release_app, release()}]
    ]
  end

  def application do
    [applications: []]
  end

  defp deps do
    [
      {:nerves, path: System.get_env("NERVES_PATH") || "../../../"},
      {:shoehorn, "~> 0.6"},
      {:system, path: "../system", targets: :target}
    ]
  end

  def release do
    [
      overwrite: true,
      steps: [&Nerves.Release.init/1, :assemble],
      strip_beams: true
    ]
  end
end
