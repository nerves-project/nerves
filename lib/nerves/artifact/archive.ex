# SPDX-FileCopyrightText: 2018 Justin Schneck
# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Artifact.Archive do
  @moduledoc false
  alias Nerves.MixUtils

  @doc "Returns the supported artifact archive extensions."
  @spec supported_extensions() :: [String.t()]
  def supported_extensions(), do: [".tar.gz", ".tar.xz", ".tar.zst"]

  @doc "Returns whether a path has a supported artifact archive extension."
  @spec valid_name?(String.t()) :: boolean()
  def valid_name?(path), do: Enum.any?(supported_extensions(), &String.ends_with?(path, &1))

  @doc """
  Extract tar file entries to a directory.

  The archive is extracted with `--strip-components=1` to remove
  the top-level directory wrapper.
  """
  @spec extract(String.t(), String.t()) :: :ok | {:error, String.t()}
  def extract(archive, destination) do
    case MixUtils.cmd("tar", ["xf", archive, "--strip-components=1", "-C", destination],
           stderr_to_stdout: true
         ) do
      {_, 0} -> :ok
      {output, _} -> {:error, "tar extraction failed: #{output}"}
    end
  end

  @doc """
  Check an artifact archive for corruption

  Returns `:ok`, if a valid artifact.
  """
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(path) do
    case file_type(path) do
      :xz -> cmd("xz", ["-t", path]) |> result()
      :gzip -> cmd("gzip", ["-t", path]) |> result()
      :zstd -> cmd("zstd", ["-tq", path]) |> result()
      _other -> {:error, "Unsupported artifact format for #{path}"}
    end
  end

  @doc "Returns corrupt artifact archives in a directory."
  @spec validate_dir(String.t()) :: [{String.t(), {:error, String.t()}}]
  def validate_dir(dir) do
    dir
    |> Path.join("*.tar.*")
    |> Path.wildcard()
    |> Enum.reduce([], fn path, corrupt ->
      case validate(path) do
        :ok -> corrupt
        {:error, _} = error -> [{path, error} | corrupt]
      end
    end)
  end

  @doc """
  Detect an archive file's type based on their header
  """
  @spec file_type(String.t()) :: :gzip | :xz | :zstd | :squashfs | :tar | :zip | :unknown | :error
  def file_type(path) do
    case File.open(path, [:read, :binary], &IO.binread(&1, 512)) do
      {:ok, bytes} when is_binary(bytes) -> type_from_bytes(bytes)
      _ -> :error
    end
  end

  defp result({"", 0}), do: :ok
  defp result({reason, _}), do: {:error, reason}

  defp cmd(cmd, args) do
    if System.find_executable(cmd) do
      MixUtils.cmd(cmd, args, stderr_to_stdout: true)
    else
      raise "Could not find '#{cmd}'. See https://nerves.hexdocs.pm/installation.html for required packages."
    end
  end

  defp type_from_bytes(<<0x1F, 0x8B, _::binary>>), do: :gzip
  defp type_from_bytes(<<0xFD, "7zXZ", _::binary>>), do: :xz
  defp type_from_bytes(<<0x28, 0xB5, 0x2F, 0xFD, _::binary>>), do: :zstd
  defp type_from_bytes(<<0x68, 0x73, 0x71, 0x73, _::binary>>), do: :squashfs
  defp type_from_bytes(<<0x50, 0x4B, 0x03, 0x04, _::binary>>), do: :zip

  # POSIX tar
  defp type_from_bytes(<<_::binary-size(257), "ustar", 0, "00", _::binary>>), do: :tar
  # GNU tar
  defp type_from_bytes(<<_::binary-size(257), "ustar  ", 0, _::binary>>), do: :tar

  defp type_from_bytes(_), do: :unknown
end
