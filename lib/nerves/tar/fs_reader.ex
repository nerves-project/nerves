# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Tar.FSReader do
  @moduledoc """
  Scan a local directory into a list of `Nerves.Tar.Entry` structs

  This is used to prep a directory to be used by `Nerves.Tar.Writer`.
  """

  alias Nerves.Tar.Entry

  @doc """
  Synthesize a directory tree

  This is useful when calling scan_directory/2 with a non-root path.
  The path should be a directory and not end with a `/`.
  """
  @spec synthesize_dirs(String.t()) :: [Entry.t()]
  def synthesize_dirs(path) do
    path |> do_synthesize_dirs([])
  end

  defp do_synthesize_dirs(path, acc) when path in ["/", ".", ""], do: acc

  defp do_synthesize_dirs(path, acc),
    do: do_synthesize_dirs(Path.dirname(path), [Entry.directory(path, mode: 0o755) | acc])

  @doc """
  Recursively scan `path` and return entries rooted at `root`

  Each file under `path` gets an entry whose path replaces the `path`
  prefix with `root`. For example:

      scan_directory("/build/rel/my_app", "srv/erlang")

  produces entries like `./srv/erlang/bin/my_app`.

  When calling this with `root` set to something besides `"/"`, be sure
  that the parent directories exist. See `synthesize_dirs/1`.
  """
  @spec scan_directory(Path.t(), String.t()) :: [Entry.t()]
  def scan_directory(path, root \\ "/") do
    abs_path = Path.expand(path)
    prefix = abs_path |> normalize_dir()
    normalized_root = normalize_dir(root)

    scan_directory(ls!(abs_path), prefix, normalized_root, [])
  end

  defp scan_directory([], _prefix, _root, acc) do
    Enum.reverse(acc)
  end

  defp scan_directory([path | rest], prefix, root, acc) do
    {stat, new_rest} =
      case File.lstat!(path) do
        %{type: :directory} = stat ->
          {stat, rest ++ ls!(path)}

        stat ->
          {stat, rest}
      end

    entry = to_entry(path, prefix, root, stat)
    scan_directory(new_rest, prefix, root, [entry | acc])
  end

  defp ls!(path) do
    File.ls!(path) |> Enum.sort() |> Enum.map(&Path.join(path, &1))
  end

  defp normalize_dir(path) do
    # Tarball directories always end with /'s
    if String.ends_with?(path, "/") do
      path
    else
      path <> "/"
    end
  end

  defp target_path(original, prefix, root) do
    String.replace(original, prefix, root)
  end

  defp to_entry(path, prefix, root, %File.Stat{type: :regular} = stat) do
    Entry.regular(target_path(path, prefix, root),
      contents: {Path.absname(path), 0},
      mode: stat.mode,
      size: stat.size
    )
  end

  defp to_entry(path, prefix, root, %File.Stat{type: :directory} = stat) do
    Entry.directory(target_path(path, prefix, root), mode: stat.mode)
  end

  defp to_entry(path, prefix, root, %File.Stat{type: :symlink} = stat) do
    Entry.symlink(target_path(path, prefix, root),
      mode: stat.mode,
      link: File.read_link!(path)
    )
  end
end
