defmodule IntegrationApp do
  use Mix.Project

  @target System.get_env("MIX_TARGET") || "system"

  def project do
    [
      app: :example_app,
      version: "0.1.0",
      archives: [nerves_bootstrap: "~> 0.7"],
      target: @target,
      aliases: aliases(),
      compilers: Mix.compilers() ++ [:host_tool],
      deps: deps()
    ]
  end

  def application do
    [applications: []]
  end

  defp deps do
    [
      {:nerves, path: System.get_env("NERVES_PATH") || "../../../"},
      {:system, path: "../system"},
      {:host_tool, path: "../host_tool"}
    ]
  end

  def aliases do
    [ 
      
    ] |> Nerves.Bootstrap.add_aliases()
  end

end
