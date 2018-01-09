defmodule Mix.Tasks.Nerves.Artifact.Archive do
  use Mix.Task

  import Mix.Nerves.IO

  require Logger

  @moduledoc """
    Create a portable archive for a specified Nerves package.

    ## Command line options
      
      `--name <archive name>`: The name of the archive. 
        Default `<package_name>-v<package_version>.<package extension>`
      `--path <path>`: The location where you want the archive to be placed.
        Default: current working dir.
      `--checksum_path`: The location where you want the `ARTIFACT_CHECKSUM` 
        file to be placed. Default: current working dir

    ## Example

      mix nerves.artifact.archive nerves_system_rpi0
  """

  @shortdoc "Nerves artifact create archive"
  @recursive true

  @switches [name: :string, path: :string, checksum_path: :string]

  def run([package_name | argv]) do
    debug_info "Nerves.Artifact.Archive start"

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
      Nerves.Package.Artifact.stale?(package, toolchain) ->
        Mix.raise "Your package sources are stale. Please run mix compile first."
      true ->
        Nerves.Package.Artifact.archive(package, toolchain, opts)
    end
    debug_info "Nerves.Artifact.Archive end"
  end
end
