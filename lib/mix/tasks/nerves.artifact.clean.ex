# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.Artifact.Clean do
  @shortdoc "Delete artifact files and build volumes"
  @moduledoc """
  Delete Nerves artifact files and container build volumes

  By default, deletes only the artifacts matching the current fingerprint of
  the specified package. Pass `--all` to every build of the artifact.

  Shows what will be deleted and asks for confirmation before proceeding.

  `MIX_TARGET` must be set so that target-specific dependencies are
  available. When no package name is given, the task auto-selects if
  there is exactly one Nerves artifact dependency.

  ## Command line options

    * `--all` - Delete all versions, not just the current one
    * `--yes` - Skip the confirmation prompt

  ## Examples

      $ MIX_TARGET=rpi0 mix nerves.artifact.clean
      $ MIX_TARGET=rpi0 mix nerves.artifact.clean test_system_rpi0
      $ MIX_TARGET=rpi0 mix nerves.artifact.clean --all test_system_rpi0
      $ MIX_TARGET=rpi0 mix nerves.artifact.clean --yes test_system_rpi0
  """
  use Mix.Task

  alias Nerves.Container
  alias Nerves.MixUtils
  alias Nerves.Paths

  @switches [all: :boolean, yes: :boolean]

  @impl Mix.Task
  @spec run([String.t()]) :: :ok
  def run(args) do
    {opts, args, _invalid} = OptionParser.parse(args, switches: @switches)

    build_plan = Nerves.build_plan()
    passed_packages = Enum.filter(build_plan.packages, fn info -> to_string(info.app) in args end)

    if length(args) != length(passed_packages) do
      Mix.raise("""
      Couldn't find packages passed on the commandline.

      Here's everything that's available:

      #{packages_to_string(build_plan.packages)}
      """)
    end

    # Select all Nerves packages to clean by default
    packages = if passed_packages != [], do: passed_packages, else: build_plan.packages

    items =
      if opts[:all] do
        Enum.flat_map(packages, &find_all_items/1)
      else
        Enum.flat_map(packages, &find_current_items/1)
      end

    cond do
      packages == [] ->
        MixUtils.warning("No Nerves packages found in the current project.")

      items == [] ->
        MixUtils.warning("Nothing to clean for #{packages_to_string(packages)}.")

      true ->
        MixUtils.info("\nWill delete:\n")
        print_items(items)
        MixUtils.info("")

        if opts[:yes] || confirm?() do
          delete_items(items)
          MixUtils.info("\nDone.")
        else
          MixUtils.info("Cancelled.")
        end
    end

    :ok
  end

  defp packages_to_string(packages) do
    Enum.map_join(packages, ", ", fn pkg -> to_string(pkg.app) end)
  end

  defp find_current_items(package) do
    downloaded_files = Path.wildcard(Path.join(package.download_path, "**/*"))
    artifact_dir = package.artifact_path
    volume = Container.volume_name(package)

    archive_items =
      if File.dir?(artifact_dir),
        do: [{:dir, artifact_dir, Paths.dir_size(artifact_dir)}],
        else: []

    dl_items = for path <- downloaded_files, do: {:file, path, File.stat!(path).size}
    volume_items = if Container.volume_exists?(volume), do: [{:volume, volume, 0}], else: []

    work_dir_items = find_work_dir_items(package)

    archive_items ++ dl_items ++ volume_items ++ work_dir_items
  end

  defp find_all_items(package) do
    artifact_dir = Paths.artifact_dir()
    dl_dir = Paths.download_dir()
    volume = Container.volume_name(package)

    artifact_dirs = Path.wildcard(Path.join(artifact_dir, "#{package.app}-*"))

    artifact_items =
      for path <- artifact_dirs, File.dir?(path), do: {:dir, path, Paths.dir_size(path)}

    downloaded_files = Path.wildcard(Path.join(dl_dir, "#{package.app}-*/**"))
    dl_items = for path <- downloaded_files, do: {:file, path, File.stat!(path).size}

    artifact_items ++ dl_items ++ find_volume_items(volume) ++ find_work_dir_items(package)
  end

  defp find_volume_items(volume) do
    if Container.volume_exists?(volume), do: [{:volume, volume, 0}], else: []
  end

  defp find_work_dir_items(package) do
    work_dir = Container.work_dir(package)
    if File.dir?(work_dir), do: [{:dir, work_dir, Paths.dir_size(work_dir)}], else: []
  end

  defp print_items(items) do
    Enum.each(items, fn
      {:dir, path, size} ->
        MixUtils.info("  Cache:    #{path}  (#{MixUtils.format_size(size)})")

      {:file, path, size} ->
        MixUtils.info("  Download: #{path}  (#{MixUtils.format_size(size)})")

      {:volume, name, _size} ->
        MixUtils.info("  Volume:   #{name}  (container build volume)")
    end)
  end

  defp delete_items(items) do
    Enum.each(items, fn
      {:dir, path, _} ->
        MixUtils.info("  Deleting #{path}")
        File.rm_rf!(path)

      {:file, path, _} ->
        MixUtils.info("  Deleting #{path}")
        File.rm!(path)

      {:volume, name, _} ->
        tool = Container.tool()
        MixUtils.info("  Removing #{tool} volume #{name}")

        case System.cmd(tool, ["volume", "rm", name], stderr_to_stdout: true) do
          {_, 0} -> :ok
          {output, _} -> MixUtils.error("    Warning: #{String.trim(output)}")
        end
    end)
  end

  defp confirm?() do
    response = Mix.shell().prompt("Delete? [y/N]")

    case response do
      :eof -> false
      text -> (String.trim(text) |> String.downcase()) in ["y", "yes"]
    end
  end
end
