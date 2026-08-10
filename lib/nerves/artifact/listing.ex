# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Artifact.Listing do
  @moduledoc false

  alias Nerves.MixUtils
  alias Nerves.Paths

  @doc """
  List cached artifact directories, returning `{name, size}` tuples.

  Optionally filter to entries whose name starts with `prefix`.
  """
  @spec list_artifacts(String.t() | nil) :: [{String.t(), non_neg_integer()}]
  def list_artifacts(prefix \\ nil) do
    artifacts_dir = Paths.artifact_dir()

    case File.ls(artifacts_dir) do
      {:ok, entries} ->
        entries
        |> maybe_filter_prefix(prefix)
        |> Enum.sort()
        |> Enum.flat_map(fn name ->
          path = Path.join(artifacts_dir, name)
          if File.dir?(path), do: [{name, Paths.dir_size(path)}], else: []
        end)

      _ ->
        []
    end
  end

  @doc """
  List downloaded archive files, returning `{name, size}` tuples.

  Optionally filter to entries whose name starts with `prefix`.
  """
  @spec list_downloads(String.t() | nil) :: [{String.t(), non_neg_integer()}]
  def list_downloads(prefix \\ nil) do
    dl_dir = Paths.download_dir()

    case File.ls(dl_dir) do
      {:ok, entries} ->
        entries
        |> maybe_filter_prefix(prefix)
        |> Enum.filter(&artifact_download?/1)
        |> Enum.sort()
        |> Enum.flat_map(fn name ->
          path = Path.join(dl_dir, name)

          case File.stat(path) do
            {:ok, %{size: size}} -> [{name, size}]
            _ -> []
          end
        end)

      _ ->
        []
    end
  end

  @doc """
  Format a list of `{name, size}` entries as aligned lines for display.

  Returns a list of formatted strings like `"  name    1.2 MB"`.
  When the list is empty, returns `["  (none)"]`.
  """
  @spec format_entries([{String.t(), non_neg_integer()}]) :: [String.t()]
  def format_entries([]), do: ["  (none)"]

  def format_entries(entries) do
    max_name = entries |> Enum.map(fn {name, _} -> String.length(name) end) |> Enum.max()
    total = entries |> Enum.map(fn {_, size} -> size end) |> Enum.sum()

    lines =
      Enum.map(entries, fn {name, size} ->
        padded = String.pad_trailing(name, max_name + 2)
        "  #{padded}#{MixUtils.format_size(size)}"
      end)

    lines ++ ["  #{String.pad_trailing("Total:", max_name + 2)}#{MixUtils.format_size(total)}"]
  end

  defp maybe_filter_prefix(entries, nil), do: entries

  defp maybe_filter_prefix(entries, prefix) do
    Enum.filter(entries, &String.starts_with?(&1, prefix))
  end

  # Check if a filename looks like a Nerves artifact download.
  # Pattern: <app>-<tuple>-<version>-<checksum>.tar.<ext>
  # where tuple is "portable", "linux_*", or "darwin_*".
  defp artifact_download?(filename) do
    String.match?(filename, ~r/^.+-(portable|linux_|darwin_).+-[A-F0-9]{7}\./i)
  end
end
