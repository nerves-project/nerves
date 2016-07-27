defmodule Mix.Tasks.Compile.NervesPackage do
  use Mix.Task

  require Logger

  @moduledoc """
    Build a Nerves Artifact from a Nerves Package
  """

  @shortdoc "Nerves Package Compiler"
  @recursive true

  def run(_args) do
    Nerves.Env.start
    config = Mix.Project.config

    package = Nerves.Env.package(config[:app])
    toolchain = Nerves.Env.toolchain

    if Nerves.Package.stale?(package, toolchain) do
      Nerves.Package.Artifact.get(package, toolchain)
    end
  end

end
