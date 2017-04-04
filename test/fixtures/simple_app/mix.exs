defmodule SimpleApp.Fixture do
  use Mix.Project

  @target System.get_env("MIX_TARGET") || "rpi3"

  def project do
    [app: :simple_app,
     version: "0.1.0",
     archives: [nerves_bootstrap: "~> 0.1"],
     target: @target,
     aliases: aliases(),
     deps: deps()]
  end

  def application do
    [applications: []]
  end

  defp deps do
    [{:system, path: "../system"}]
  end

  def aliases do
    ["deps.precompile": ["nerves.precompile", "deps.precompile"],
     "deps.loadpaths":  ["deps.loadpaths",    "nerves.loadpaths"]]
  end

end
