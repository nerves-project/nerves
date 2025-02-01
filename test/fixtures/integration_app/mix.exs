defmodule IntegrationApp do
  use Mix.Project

  def project() do
    [
      app: :integration_app,
      version: "0.1.0",
      archives: [nerves_bootstrap: "~> 1.0"],
      deps: deps()
    ]
  end

  def application() do
    [extra_applications: []]
  end

  defp deps() do
    [
      {:nerves, path: "../../../..", runtime: false},
      {:system, path: "../system", runtime: false}
    ]
  end
end
