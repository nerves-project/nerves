defmodule Mix.Tasks.Nerves.Artifact.Archive do
  use Mix.Task

  import Mix.Nerves.IO

  require Logger

  @moduledoc """
    Create a portable archive for a specified Nerves package
  """

  @shortdoc "Nerves artifact archive"
  @recursive true

  def run([app | opts]) do
    debug_info "nerves.artifact.archive start"

    Nerves.Env.start
    Nerves.Env.ensure_loaded(Mix.Project.config[:app])

    package = 
      app
      |> String.to_atom()
      |> Nerves.Env.package()
    toolchain = Nerves.Env.toolchain
    cond do
      package == nil ->
        Mix.raise "Could not find Nerves package #{app} in env"
      Nerves.Package.Artifact.stale?(package, toolchain) ->
        Mix.raise "Your package sources are stale. Please run mix compile first."
      true ->
        Nerves.Package.Artifact.archive(package, toolchain, opts)
    end
    debug_info "nerves.artifact.archive end"
  end
end
