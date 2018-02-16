defmodule SimpleAppArtifact.Fixture do
  use Mix.Project

  @target System.get_env("MIX_TARGET") || "system"

  def project do
    [
      app: :simple_app_artifact,
      version: "0.1.0",
      archives: [nerves_bootstrap: "~> 1.0-rc"],
      target: @target,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [applications: []]
  end

  defp deps do
    [
      {:system_artifact, path: "../system_artifact"}
    ]
  end

  def aliases do
    [] |> Nerves.Bootstrap.add_aliases()
  end
end
