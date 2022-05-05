defmodule IntegrationApp do
  use Mix.Project

  def project() do
    [
      app: :example_app,
      version: "0.1.0",
      archives: [nerves_bootstrap: "~> 1.0"],
      compilers: Mix.compilers() ++ [:host_tool],
      deps: deps()
    ]
  end

  def application() do
    [applications: []]
  end

  defp deps() do
    [
      {:nerves, path: System.get_env("NERVES_PATH") || "../../../"},
      {:system, path: "../system"},
      {:host_tool, path: "../host_tool"}
    ]
  end
end
