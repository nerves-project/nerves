# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Paths do
  @moduledoc false
  import Bitwise
  alias Nerves.MixUtils

  @spec data_dir() :: String.t()
  def data_dir() do
    case System.get_env("XDG_DATA_HOME") do
      nil -> Path.join(System.user_home!(), ".nerves")
      path -> Path.join(path, "nerves")
    end
  end

  @spec download_dir() :: String.t()
  def download_dir() do
    Path.expand(System.get_env("NERVES_DL_DIR") || Path.join(data_dir(), "dl"))
  end

  @spec download_dir(atom(), Version.t()) :: String.t()
  def download_dir(app, version) do
    Path.join(download_dir(), "#{app}-#{version}")
  end

  @spec artifact_dir() :: String.t()
  def artifact_dir() do
    Path.expand(System.get_env("NERVES_ARTIFACTS_DIR") || Path.join(data_dir(), "artifacts"))
  end

  @spec artifact_dir(atom(), Version.t()) :: String.t()
  def artifact_dir(app, version) do
    Path.join(artifact_dir(), "#{app}-#{version}")
  end

  @doc """
  Find all executable binaries in the specified directory and below

  This function skips directories with the Nerves 1.x `.noscrub` file.
  """
  @spec executable_paths(Path.t()) :: [Path.t()]
  def executable_paths(path) do
    {dirs, execs} =
      Enum.reduce_while(File.ls!(path), {[], []}, fn entry, {d, e} ->
        child = Path.join(path, entry)
        st = File.lstat!(child)

        cond do
          st.type == :directory -> {:cont, {[child | d], e}}
          st.type == :regular and (st.mode &&& 0o100) != 0 -> {:cont, {d, [child | e]}}
          entry == ".noscrub" -> {:halt, {[], []}}
          true -> {:cont, {d, e}}
        end
      end)

    child_execs = Enum.flat_map(dirs, &executable_paths/1)
    execs ++ child_execs
  end

  @doc """
  Compute the total disk usage of a directory

  Shells out to `du -ks` to handle symlinks, hardlinks, and sparse files.
  """
  @spec dir_size(String.t()) :: non_neg_integer()
  def dir_size(path) do
    case MixUtils.cmd("du", ["-ks", path], stderr_to_stdout: true) do
      {output, 0} ->
        output
        |> String.split("\t")
        |> List.first("0")
        |> String.trim()
        |> String.to_integer()
        |> Kernel.*(1024)

      _ ->
        0
    end
  end

  @doc """
  Expand a list of file patterns to a list of absolute paths

  The input for this are file lists like the `:artifact_source_files` Nerves field
  in the `mix.exs` or the hex package `:files` field.  It can contain
  wildcards or point to directories or files.

  Note: This matches the original Nerves checksum algorithm with the exception that missing
  files don't get pruned. In other words, missing files will result in an error now rather
  than being silently skipped.
  """
  @spec expand_file_patterns([String.t()], String.t()) :: [Path.t()]
  def expand_file_patterns(paths, base_path) do
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
