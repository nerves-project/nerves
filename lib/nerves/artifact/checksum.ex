# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Artifact.Checksum do
  @moduledoc false

  @spec digest!(Path.t()) :: binary()
  def digest!(path) do
    path
    |> File.stream!(64 * 1024, [])
    |> Enum.reduce(:crypto.hash_init(:sha256), &:crypto.hash_update(&2, &1))
    |> :crypto.hash_final()
  end

  @spec checksum!(Path.t()) :: String.t()
  def checksum!(path) do
    "sha256:" <> Base.encode16(digest!(path), case: :lower)
  end

  @spec read!(Path.t()) :: %{String.t() => String.t()}
  def read!(path) do
    with {:ok, contents} <- File.read(path),
         {:ok, {:%{}, _, pairs}} <- Code.string_to_quoted(contents),
         true <- Enum.all?(pairs, &valid_entry?/1),
         checksums = Map.new(pairs),
         true <- map_size(checksums) == length(pairs) do
      checksums
    else
      {:error, reason} when is_atom(reason) ->
        Mix.raise("Could not read checksum manifest #{path}: #{:file.format_error(reason)}")

      _ ->
        Mix.raise("Invalid checksum manifest #{path}: expected a literal map of SHA256 checksums")
    end
  end

  defp valid_entry?({filename, checksum}) when is_binary(filename) and is_binary(checksum) do
    Regex.match?(~r/\Asha256:[0-9a-f]{64}\z/, checksum)
  end

  defp valid_entry?(_), do: false

  @spec write!(Path.t(), %{String.t() => String.t()}) :: :ok
  def write!(path, checksums) do
    entries =
      checksums
      |> Enum.sort()
      |> Enum.map(fn {filename, checksum} ->
        ["  ", inspect(filename), " => ", inspect(checksum), ",\n"]
      end)

    File.write!(path, ["%{\n", entries, "}\n"])
  end
end
