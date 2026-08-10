# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.Artifact.Ls do
  @shortdoc "List cached Nerves artifacts"
  @moduledoc """
  List cached Nerves artifacts, downloaded archives, and container build volumes.

  ## Examples

      $ mix nerves.artifact.ls
  """
  use Mix.Task

  alias Nerves.Artifact.Listing
  alias Nerves.Container
  alias Nerves.MixUtils
  alias Nerves.Paths

  @impl Mix.Task
  @spec run([String.t()]) :: :ok
  def run(_args) do
    artifacts_dir = Paths.artifact_dir()
    dl_dir = Paths.download_dir()

    MixUtils.info("""
    Cached artifacts (#{artifacts_dir}):
    #{Listing.list_artifacts() |> Listing.format_entries() |> Enum.join("\n")}

    Downloads (#{dl_dir}):
    #{Listing.list_downloads() |> Listing.format_entries() |> Enum.join("\n")}

    Container build volumes:
    #{list_volumes()}
    """)
  end

  defp list_volumes() do
    case Container.list_docker_volumes() do
      [] -> "  (none)\n"
      volumes -> Enum.map_join(volumes, "\n", fn name -> "  #{name}" end)
    end
  end
end
