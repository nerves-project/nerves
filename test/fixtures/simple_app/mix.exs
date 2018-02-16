defmodule SimpleApp.Fixture do
  use Mix.Project

  @target System.get_env("MIX_TARGET") || "system"

  def project do
    [
      app: :simple_app,
      version: "0.1.0",
      archives: [nerves_bootstrap: "~> 0.7"],
      target: @target,
      deps: deps(),
      aliases: Nerves.Bootstrap.add_aliases([])
    ]
  end

  def application do
    [applications: []]
  end

  defp deps do
    [
      {:system, path: "../system"}
    ]
  end
end
