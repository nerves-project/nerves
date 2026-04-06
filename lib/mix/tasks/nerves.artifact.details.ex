# SPDX-FileCopyrightText: 2022 Jon Carstens
# SPDX-FileCopyrightText: 2022 Udo Schneider
#
# SPDX-License-Identifier: Apache-2.0
#
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
    Name:               #{package.app}
    Version:            #{package.version}
    Checksum:           #{Artifact.checksum(package)}
    Acceptable archive names: #{Enum.join(Artifact.archive_names(package), ", ")}
    Downloaded archive: #{Artifact.cached_archive_path(package)}
    Artifact location:  #{Artifact.dir(package)}
    Sites:              #{inspect(Keyword.get(package.config, :artifact_sites, []))}
    """)

    debug_info("Nerves.Artifact.Details end")
  end
end
