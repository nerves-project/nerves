defmodule Nerves.Release.RootfsPriorities do
  @moduledoc false

  # No leading '/' here since this is passed to mksquashfs and it
  # doesn't like the leading slash.
  @target_release_path "srv/erlang"

  def write_rootfs_priorities(applications, host_release_path, bootfile) do
    applications = normalize_applications(applications)

    {:script, _, boot_script} = :erlang.binary_to_term(bootfile)

    target_beam_files = target_beam_files(boot_script, host_release_path)
    target_app_files = target_app_files(applications)
    target_priv_dirs = target_priv_dirs(applications)

    priorities =
      (target_beam_files ++ target_app_files ++ target_priv_dirs)
      |> List.flatten()
      |> Enum.zip(32_000..1_000//-1)
      |> Enum.map(fn {file, priority} -> [file, " ", to_string(priority), "\n"] end)

    build_path = Path.join([Mix.Project.build_path(), "nerves"])
    File.mkdir_p!(build_path)

    Path.join(build_path, "rootfs.priorities")
    |> File.write(priorities)
  end

  defp target_beam_files(boot_script, host_release_path) do
    {_, loaded} =
      Enum.reduce(boot_script, {nil, []}, fn
        {:path, paths}, {_, loaded} ->
          {rel_paths(paths), loaded}

        {:primLoad, files}, {paths, loaded} ->
          prim_loaded =
            for path <- paths,
                file <- files,
                path = Path.join(["lib", path, "#{file}.beam"]),
                host_path = Path.expand(Path.join(host_release_path, path)),
                File.exists?(host_path),
                reduce: [] do
              acc ->
                [expand_target_path(path) | acc]
            end

          {paths, [prim_loaded | loaded]}

        _, acc ->
          acc
      end)

    loaded
    |> Enum.reverse()
    |> List.flatten()
  end

  defp rel_paths(paths) do
    paths
    |> Enum.reverse()
    |> Enum.map(&to_string/1)
    |> Enum.map(&Path.split/1)
    |> Enum.map(fn [_root | path] ->
      Path.join(path)
    end)
  end

  defp not_empty_dir(dir) do
    File.ls(dir) != {:ok, []}
  end

  defp expand_target_path(path) do
    Path.join(["/", @target_release_path, path])
    |> Path.expand(@target_release_path)
    |> String.trim_leading("/")
  end

  defp target_app_files(applications) do
    for {app, vsn, path} <- applications,
        host_path = Path.join([path, "ebin", "#{app}.app"]),
        File.exists?(host_path),
        reduce: [] do
      acc ->
        app_path = Path.join([@target_release_path, "lib", "#{app}-#{vsn}", "ebin", "#{app}.app"])
        [app_path | acc]
    end
  end

  defp target_priv_dirs(applications) do
    for {app, vsn, path} <- applications,
        host_priv_dir = Path.join(path, "priv"),
        File.dir?(host_priv_dir),
        not_empty_dir(host_priv_dir),
        reduce: [] do
      acc ->
        priv_path = Path.join([@target_release_path, "lib", "#{app}-#{vsn}", "priv"])
        [priv_path | acc]
    end
  end

  defp normalize_applications(applications) do
    for {app, opts} <- applications do
      {to_string(app), to_string(opts[:vsn]), Path.expand(opts[:path] || "")}
    end
  end
end
