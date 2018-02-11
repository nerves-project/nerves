defmodule Mix.Tasks.Compile.NervesPackage do
  use Mix.Task
  import Mix.Nerves.IO

  require Logger

  @moduledoc """
    Build a Nerves Artifact from a Nerves Package
  """

  @shortdoc "Nerves Package Compiler"
  @recursive true

  def run(_args) do
    debug_info("Compile.NervesPackage start")
    config = Mix.Project.config()

    Nerves.Env.start()
    Nerves.Env.ensure_loaded(Mix.Project.config()[:app])

    package = Nerves.Env.package(config[:app])
    toolchain = Nerves.Env.toolchain()

    ret =
      if Nerves.Env.enabled?() and Nerves.Artifact.stale?(package) do
        Nerves.Artifact.build(package, toolchain)
        :ok
      else
        :noop
      end

    debug_info("Compile.NervesPackage end")
    ret
  end
end
