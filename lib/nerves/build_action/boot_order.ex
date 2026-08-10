# SPDX-FileCopyrightText: 2019 Justin Schneck
# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.BuildAction.BootOrder do
  @moduledoc """
  Sorts tar entries to optimize boot performance.

  Parses the OTP boot script to determine the order that `.beam` files
  are loaded during startup. Files loaded early are placed earlier in
  the tar archive (and thus earlier in the squashfs image), reducing
  disk seeks during boot.

  ## Priority order

    1. `.beam` files in their boot script load order (`:primLoad` directives)
    2. `.app` files for each application
    3. Non-empty `priv` directories for each application
    4. All remaining files (alphabetically)

  Directories always sort before non-directories so that parent entries
  appear before their children.
  """

  alias Nerves.Tar.Entry

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Sort tar entries with boot-critical files first.

  Directories always come first (alphabetically among themselves).
  Among non-directory entries, those referenced in the boot script sort
  next in their load order, followed by all remaining entries
  alphabetically.
  """
  @spec sort([Entry.t()], %{String.t() => non_neg_integer()}) :: [Entry.t()]
  def sort(entries, priority_map) do
    Enum.sort(entries, &compare(&1, &2, priority_map))
  end

  @doc """
  Build a priority map from a Mix release.

  Reads the configured boot script (defaults to `start.boot`) and
  returns a map of normalized tar paths to priority numbers (0 = highest).
  Returns an empty map if the boot script cannot be read.

  ## Examples

      priority_map = BootOrder.build_priority_map(release)
      sorted = BootOrder.sort(entries, priority_map)
  """
  @spec build_priority_map(Mix.Release.t(), map()) :: %{String.t() => non_neg_integer()}
  def build_priority_map(%Mix.Release{} = release, opts) do
    target_release_path = opts[:target_release_path]
    bootfile = opts[:bootfile]
    bootfile_path = Path.join([release.version_path, bootfile])

    case File.read(bootfile_path) do
      {:ok, binary} ->
        {:script, _, boot_script} = :erlang.binary_to_term(binary)
        applications = normalize_applications(release.applications)

        priority_paths(boot_script, applications, release.path, target_release_path)
        |> to_priority_map()

      {:error, _} ->
        %{}
    end
  end

  @doc """
  Build the ordered list of prioritized target paths from a boot script.

  The returned paths are relative to the target root without a leading
  `./` (e.g., `srv/erlang/lib/kernel-10.0/ebin/kernel.beam`). Files
  are returned in boot load order: beam files first (in `:primLoad`
  order), then `.app` files, then priv directories.

  `applications` should be a list of `{app_name, version, host_path}`
  string tuples — see `normalize_applications/1`.
  """
  @spec priority_paths(term(), [{String.t(), String.t(), String.t()}], String.t(), String.t()) ::
          [String.t()]
  def priority_paths(boot_script, applications, host_release_path, target_release_path) do
    beam_files = target_beam_files(boot_script, host_release_path, target_release_path)
    app_files = target_app_files(applications, target_release_path)
    priv_dirs = target_priv_dirs(applications, target_release_path)

    List.flatten(beam_files ++ app_files ++ priv_dirs)
  end

  @doc """
  Convert a list of target paths to a priority map.

  Paths are prefixed with `./` to match tar entry format. Lower numbers
  indicate higher priority (should appear first in the archive).
  """
  @spec to_priority_map([String.t()]) :: %{String.t() => non_neg_integer()}
  def to_priority_map(paths) do
    paths
    |> Enum.with_index()
    |> Map.new(fn {path, idx} -> {"./#{path}", idx} end)
  end

  @doc """
  Normalize `Mix.Release` applications into `{app, vsn, path}` tuples.
  """
  @spec normalize_applications([{atom(), keyword()}]) :: [{String.t(), String.t(), String.t()}]
  def normalize_applications(applications) do
    for {app, opts} <- applications do
      {to_string(app), to_string(opts[:vsn]), Path.expand(opts[:path] || "")}
    end
  end

  # ---------------------------------------------------------------------------
  # Comparison
  # ---------------------------------------------------------------------------

  defp compare(a, b, priority_map) do
    case {a.type, b.type} do
      {:directory, :directory} -> a.path <= b.path
      {:directory, _} -> true
      {_, :directory} -> false
      _ -> compare_by_priority(a.path, b.path, priority_map)
    end
  end

  defp compare_by_priority(path_a, path_b, priority_map) do
    pri_a = Map.get(priority_map, path_a)
    pri_b = Map.get(priority_map, path_b)

    case {pri_a, pri_b} do
      {nil, nil} -> path_a <= path_b
      {nil, _} -> false
      {_, nil} -> true
      {a, b} -> a <= b
    end
  end

  # ---------------------------------------------------------------------------
  # Boot script parsing
  # ---------------------------------------------------------------------------

  defp target_beam_files(boot_script, host_release_path, target_release_path) do
    {_, loaded} =
      Enum.reduce(boot_script, {nil, []}, fn
        {:path, paths}, {_, loaded} ->
          {rel_paths(paths), loaded}

        {:primLoad, files}, {paths, loaded} ->
          prim_loaded =
            for path <- paths || [],
                file <- files,
                path = Path.join(["lib", path, "#{file}.beam"]),
                host_path = Path.expand(Path.join(host_release_path, path)),
                File.exists?(host_path),
                reduce: [] do
              acc ->
                [expand_target_path(path, target_release_path) | acc]
            end

          {paths, [prim_loaded | loaded]}

        _, acc ->
          acc
      end)

    loaded
    |> Enum.reverse()
    |> List.flatten()
  end

  @doc false
  @spec target_app_files([{String.t(), String.t(), String.t()}], String.t()) :: [String.t()]
  def target_app_files(applications, target_release_path) do
    applications
    |> Enum.reduce([], fn {app, vsn, path}, acc ->
      host_path = Path.join([path, "ebin", "#{app}.app"])

      if File.exists?(host_path) do
        app_path =
          Path.join([target_release_path, "lib", "#{app}-#{vsn}", "ebin", "#{app}.app"])

        [app_path | acc]
      else
        acc
      end
    end)
    |> Enum.sort()
  end

  @doc false
  @spec target_priv_dirs([{String.t(), String.t(), String.t()}], String.t()) :: [String.t()]
  def target_priv_dirs(applications, target_release_path) do
    applications
    |> Enum.reduce([], fn {app, vsn, path}, acc ->
      host_priv_dir = Path.join(path, "priv")

      if File.dir?(host_priv_dir) and not_empty_dir?(host_priv_dir) do
        priv_path = Path.join([target_release_path, "lib", "#{app}-#{vsn}", "priv"])
        [priv_path | acc]
      else
        acc
      end
    end)
    |> Enum.sort()
  end

  # ---------------------------------------------------------------------------
  # Path helpers
  # ---------------------------------------------------------------------------

  # Convert boot script code paths to relative form.
  #
  # Boot script paths are charlists like '$RELEASE_LIB/kernel-10.0/ebin'.
  # This strips the variable prefix (first path component) and returns
  # the relative portion (e.g., "kernel-10.0/ebin").
  defp rel_paths(paths) do
    paths
    |> Enum.reverse()
    |> Enum.map(&to_string/1)
    |> Enum.map(&Path.split/1)
    |> Enum.map(fn [_root | path] -> Path.join(path) end)
  end

  # Map a host-relative path to the target rootfs path under target_release_path
  #
  # Path.expand resolves any ".." in the path, which is important for
  # consolidated protocol paths that use "$RELEASE_LIB/../releases/..."
  # to correctly resolve to "srv/erlang/releases/..." (not
  # "srv/erlang/lib/releases/...").
  defp expand_target_path(path, target_release_path) do
    Path.join(["/", target_release_path, path])
    |> Path.expand(target_release_path)
    |> String.trim_leading("/")
  end

  defp not_empty_dir?(dir) do
    File.ls(dir) != {:ok, []}
  end
end
