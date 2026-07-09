# SPDX-FileCopyrightText: 2026 Thomas Winkler
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Artifact.BuildRunners.Container.Instance do
  @moduledoc false
  import Nerves.Artifact.BuildRunners.Container.Utils

  @doc """
  All containers (any state) that reference one of the given named volumes.
  Returns `%{id: String.t(), state: String.t()}` entries; fails open with `[]`
  when the CLI or JSON output is unavailable.
  """
  @spec using_volumes([String.t()]) :: [%{id: String.t(), state: String.t()}]
  def using_volumes(volumes) do
    with {result, 0} <-
           System.cmd("container", ["list", "--all", "--format", "json"], stderr_to_stdout: true),
         {:ok, containers} <- Jason.decode(result) do
      containers
      |> Enum.filter(&references_volume?(&1, volumes))
      |> Enum.map(fn container ->
        %{
          id: container["id"] || get_in(container, ["configuration", "id"]),
          state: get_in(container, ["status", "state"]) || "stopped"
        }
      end)
    else
      _ -> []
    end
  end

  defp references_volume?(container, volumes) do
    container
    |> get_in(["configuration", "mounts"])
    |> List.wrap()
    |> Enum.any?(fn
      %{"type" => %{"volume" => %{"name" => name}}} -> name in volumes
      _ -> false
    end)
  end

  @spec stop(String.t()) :: :ok
  def stop(id) do
    shell_info("Stopping container #{id}")
    _ = System.cmd("container", ["stop", id], stderr_to_stdout: true)
    :ok
  end

  @spec delete(String.t()) :: :ok
  def delete(id) do
    shell_info("Removing container #{id}")
    _ = System.cmd("container", ["delete", id], stderr_to_stdout: true)
    :ok
  end
end
