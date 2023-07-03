defmodule IntegrationApp do
  use Mix.Project

  def project() do
    [
      app: :integration_app,
      version: "0.1.0",
      archives: [nerves_bootstrap: "~> 1.0"],
      compilers: Mix.compilers() ++ [:host_tool],
      deps: deps()
    ]
  end

  def application() do
    [extra_applications: []]
  end

  defp deps() do
    [
      {:nerves, path: System.get_env("NERVES_PATH") || "../../../", runtime: false},
      {:system, path: "../system", runtime: false},
      {:host_tool, path: "../host_tool", runtime: false}
    ]
  end
end
