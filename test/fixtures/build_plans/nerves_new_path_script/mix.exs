defmodule NervesNewPathScript.MixProject do
  use Mix.Project

  @app :nerves_new_path_script
  @version "0.1.0"

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.17",
      archives: [nerves_bootstrap: ">= 0.0.0"],
      compilers: Mix.compilers() ++ [:fixture_path],
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:cover_helper, path: "../../cover_helper", runtime: false},
      {:nerves, path: "../../../..", override: true, runtime: false},
      {:nerves_host_tools, path: "../nerves_host_tools", runtime: false}
    ]
  end
end
