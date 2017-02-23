defmodule Mix.Tasks.Compile.NervesPackage do
  use Mix.Task

  require Logger

  @moduledoc """
    Build a Nerves Artifact from a Nerves Package
  """

  @shortdoc "Nerves Package Compiler"
  @recursive true

  def run(_args) do
    config = Mix.Project.config

    Nerves.Env.start
    Nerves.Env.ensure_loaded(Mix.Project.config[:app])

    package = Nerves.Env.package(config[:app])
    toolchain = Nerves.Env.toolchain

    if Nerves.Env.enabled? and Nerves.Package.stale?(package, toolchain) do
      Nerves.Package.artifact(package, toolchain)
    end

  end

end
