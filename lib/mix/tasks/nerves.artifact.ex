defmodule Mix.Tasks.Nerves.Artifact do
  use Mix.Task

  import Mix.Nerves.IO

  require Logger

  @moduledoc """
    Create an artifac for a specified Nerves package.

    ## Command line options
      
      `--path <path>`: The location where you want the archive to be placed.
        Default: $NERVES_DL_DIR || ~/.nerves/dl

    ## Example

      mix nerves.artifact nerves_system_rpi0
  """

  @shortdoc "Nerves create artifact"
  @recursive true

  @switches [path: :string]

  def run([package_name | argv]) do
    debug_info "Nerves.Artifact start"

    {opts, _, _} = OptionParser.parse(argv, switches: @switches)

    Nerves.Env.start
    Nerves.Env.ensure_loaded(Mix.Project.config[:app])

    package = 
      package_name
      |> String.to_atom()
      |> Nerves.Env.package()
    toolchain = Nerves.Env.toolchain
    cond do
      package == nil ->
        Mix.raise "Could not find Nerves package #{package_name} in env"
      Nerves.Artifact.stale?(package) ->
        Mix.raise "Your package sources are stale. Please run mix compile first."
      true ->
        Nerves.Artifact.archive(package, toolchain, opts)
    end
    debug_info "Nerves.Artifact end"
  end
end
