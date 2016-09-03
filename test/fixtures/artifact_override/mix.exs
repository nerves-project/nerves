defmodule ArtifactOverride.Fixture do
  use Mix.Project

  @target System.get_env("NERVES_TARGET") || "rpi3"

  def project do
    [app: :artifact_override,
     version: "0.1.0",
     archives: [nerves_bootstrap: "~> 0.1"],
     target: @target,
     aliases: aliases(),
     artifacts: artifacts(),
     deps: deps()]
  end

  def application do
    [applications: []]
  end

  defp deps do
    [{:package, path: "../package"},
     {:system, path: "../system"}]
  end

  def aliases do
    ["deps.precompile": ["nerves.precompile", "deps.precompile"],
     "deps.loadpaths":  ["deps.loadpaths",    "nerves.loadpaths"]]
  end

  def artifacts do
    [{:system, Nerves.Package.Providers.Docker},
     {:toolchain, url: "http://foo.bar/artifact.tar.gz"},
     {:package, path: "/path/to/artifact"}]
  end

end
