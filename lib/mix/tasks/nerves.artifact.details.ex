defmodule Mix.Tasks.Nerves.Artifact.Details do
  @shortdoc "Prints Nerves artifact details"
  @moduledoc """
  Prints Nerves artifact details.

  This displays various details.

  ## Examples

      $ mix nerves.artifact.details nerves_system_rpi0

  If the command is called without the package name,
  `Nerves.Project.config()[:app]` will be used by default.
  """
  use Mix.Task

  import Mix.Nerves.IO

  alias Nerves.Artifact

  require Logger

  @recursive true

  @impl Mix.Task
  def run(argv) do
    debug_info("Nerves.Artifact.Details start")

    # We should have attempted precompile before this, but run it
    # here just in case. Noop if it has already been run.
    Mix.Task.run("nerves.precompile", [])

    package_name =
      case OptionParser.parse(argv, switches: []) do
        {_, [p | _], _} -> String.to_atom(p)
        _ -> Mix.Project.config()[:app]
      end

    package = Nerves.Env.package(package_name)

    if is_nil(package), do: Mix.raise("Could not find Nerves package #{package_name} in env")

    Mix.shell().info("""
    Version:            #{package.version}
    Checksum:           #{Artifact.checksum(package)}
    Checksum Short:     #{Artifact.checksum(package, short: Artifact.__checksum_short_length__())}
    Name:               #{Artifact.name(package)}
    Download Name:      #{Artifact.download_name(package)}
    Download File Name: #{Artifact.download_name(package)}#{Artifact.ext(package)}
    Download Path:      #{Artifact.download_path(package)}
    Sites:              #{inspect(Keyword.get(package.config, :artifact_sites, []))}
    Base Directory:     #{Artifact.base_dir()}
    Path:               #{Artifact.dir(package)}
    Build Path:         #{Artifact.build_path(package)}
    """)

    debug_info("Nerves.Artifact.Details end")
  end
end
