defmodule ReleaseApp.Fixture do
  use Mix.Project

  def project() do
    [
      app: :release_app,
      version: "0.1.0",
      deps: deps(),
      releases: [{:release_app, release()}],
      application: application()
    ]
  end

  def application() do
    [extra_applications: [:logger, :runtime_tools]]
  end

  defp deps() do
    [
      {:nerves, path: System.get_env("NERVES_PATH") || "../../../"},
      {:shoehorn, "~> 0.9"},
      {:system, path: "../system", targets: :target}
    ]
  end

  def release() do
    [
      overwrite: true,
      steps: [&Nerves.Release.init/1, :assemble],
      rel_templates_path: System.get_env("REL_TEMPLATES_PATH", "rel"),
      strip_beams: true
    ]
  end
end
