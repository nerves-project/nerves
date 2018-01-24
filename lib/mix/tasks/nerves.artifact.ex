defmodule Mix.Tasks.Nerves.Artifact do
  use Mix.Task

  import Mix.Nerves.IO

  require Logger

  @moduledoc """
    Create an artifact for a specified Nerves package.

    ## Command line options
      
      `--path <path>`: The location where you want the archive to be placed.
        Default: $NERVES_DL_DIR || ~/.nerves/dl

    ## Example

      $ mix nerves.artifact nerves_system_rpi0

    If the command is called without the package name, 
    Nerves.Project.config()[:app] will be used by default.

      $ mix nerves.artifact --path /tmp
  """

  @shortdoc "Nerves create artifact"
  @recursive true

  @switches [path: :string]

  def run(argv) do
    {package_name, argv} = 
      case argv do
        ["-" <> _arg | _] ->
          {Mix.Project.config()[:app], argv}
        [package_name | argv] -> 
          {package_name, argv}
      end
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
