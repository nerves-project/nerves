defmodule SimpleAppArtifact.Fixture do
  use Mix.Project

  def project() do
    [
      app: :simple_app_artifact,
      version: "0.1.0",
      archives: [nerves_bootstrap: "~> 1.0"],
      deps: deps()
    ]
  end

  def application() do
    [applications: []]
  end

  defp deps() do
    [
      {:system_artifact, path: "../system_artifact"}
    ]
  end
end
