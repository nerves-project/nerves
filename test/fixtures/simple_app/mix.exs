defmodule SimpleApp.Fixture do
  use Mix.Project

  def project do
    [
      app: :simple_app,
      version: "0.1.0",
      archives: [nerves_bootstrap: "~> 1.0"],
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
