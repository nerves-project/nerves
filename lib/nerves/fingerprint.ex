# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Fingerprint do
  # The checksum covers the files listed in the package's `source_fingerprint_files`.
  # Each file is individually SHA256-hashed, then all hashes are concatenated
  # and hashed again.
  #
  # This is NOT a security feature. It helps guard against using stale build artifacts.
  @moduledoc false

  @spec fingerprint([String.t()], String.t()) :: String.t()
  def fingerprint(files, base_path) do
    checksum(files, base_path)
    |> String.slice(0, 7)
  end

  @doc """
  Compute a SHA256-based checksum over a list of source manifest files.

  `files` is the raw list of paths/globs from `nerves_package[:source_fingerprint_files]`.
  `base_path` is the package root directory used to expand relative entries.
  """
  @spec checksum([String.t()], String.t()) :: String.t()
  def checksum(files, base_path) do
    blob =
      files
      |> expand_paths(base_path)
      |> Enum.map(&File.read!/1)
      |> Enum.map(&:crypto.hash(:sha256, &1))

    :crypto.hash(:sha256, blob)
    |> Base.encode16()
  end

  # Expand file paths relative to the package root, handling directories and globs.
  # This matches the original Nerves checksum algorithm with the exception that missing
  # files don't get pruned.
  defp expand_paths(paths, base_path) do
    paths
    |> Enum.map(&Path.join(base_path, &1))
    |> Enum.flat_map(&expand/1)
    |> Enum.map(&Path.expand/1)
    |> Enum.uniq()
  end

  defp expand(path) do
    cond do
      String.contains?(path, "*") -> regular_wildcard(path)
      File.dir?(path) -> regular_wildcard(Path.join(path, "**"))
      true -> [path]
    end
  end

  defp regular_wildcard(path) do
    Path.wildcard(path) |> Enum.filter(&File.regular?/1)
  end
end
