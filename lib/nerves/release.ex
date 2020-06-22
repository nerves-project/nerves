defmodule Nerves.Release do
  # No leading '/' here since this is passed to mksquashfs and it
  # doesn't like the leading slash.
  @target_release_path "srv/erlang"

  def init(%{options: options} = release) do
    opts = Keyword.merge(options, release_opts())

    release = %{
      release
      | options: opts,
        steps: release.steps ++ [&Nerves.Release.finalize/1]
    }

    File.rm_rf!(release.path)

    if Code.ensure_loaded?(Shoehorn.Release) do
      apply(Shoehorn.Release, :init, [release])
    else
      release
    end
  end

  def finalize(release) do
    bootfile_path = Path.join([release.version_path, bootfile()])

    case File.read(bootfile_path) do
      {:ok, bootfile} ->
        Nerves.Release.write_rootfs_priorities(release.applications, release.path, bootfile)

      _ ->
        Nerves.Utils.Shell.warn("""
          Unable to load bootfile: #{inspect(bootfile_path)}
          Skipping rootfs priority file generation
        """)
    end

    release
  end

  def bootfile() do
    Application.get_env(:nerves, :firmware)[:bootfile] || "shoehorn.boot"
  end

  def erts() do
    if Nerves.Env.loaded?() do
      System.get_env("ERTS_DIR")
    else
      true
    end
  end

  def write_rootfs_priorities(applications, host_release_path, bootfile) do
    # Distillery support
    applications = normalize_applications(applications)

    target_release_path = @target_release_path

    {:script, _, boot_script} = :erlang.binary_to_term(bootfile)

    target_beam_files = target_beam_files(boot_script, host_release_path, target_release_path)
    target_app_files = target_app_files(applications, target_release_path)
    target_priv_dirs = target_priv_dirs(applications, target_release_path)

    priorities =
      (target_beam_files ++ target_app_files ++ target_priv_dirs)
      |> List.flatten()
      |> Enum.zip(32_000..1_000)
      |> Enum.map(fn {file, priority} ->
        file <> " " <> to_string(priority)
      end)
      |> Enum.join("\n")

    build_path = Path.join([Mix.Project.build_path(), "nerves"])
    File.mkdir_p!(build_path)

    Path.join(build_path, "rootfs.priorities")
    |> File.write(priorities)
  end

  defp target_beam_files(boot_script, host_release_path, target_release_path) do
    {_, loaded} =
      Enum.reduce(boot_script, {nil, []}, fn
        {:path, paths}, {_, loaded} ->
          {rel_paths(paths), loaded}

        {:primLoad, files}, {paths, loaded} ->
          load =
            Enum.reduce(paths, [], fn path, loaded ->
              load =
                Enum.reduce(files, [], fn file, loaded ->
                  filename = to_string(file) <> ".beam"

                  path =
                    if String.starts_with?(path, "lib/") do
                      # Distillery
                      Path.join([path, filename])
                    else
                      # Elixir 1.9 releases
                      Path.join(["lib", path, filename])
                    end

                  host_path = Path.join(host_release_path, path) |> Path.expand()

                  if File.exists?(host_path) do
                    [expand_target_path(target_release_path, path) | loaded]
                  else
                    loaded
                  end
                end)

              loaded ++ load
            end)

          {paths, [load | loaded]}

        _, acc ->
          acc
      end)

    loaded
    |> Enum.reverse()
    |> List.flatten()
  end

  defp target_app_files(applications, target_release_path) do
    Enum.reduce(applications, [], fn
      {app, vsn, path}, app_files ->
        host_path = Path.join([path, "ebin", app <> ".app"])

        if File.exists?(host_path) do
          app_file_path =
            Path.join([
              target_release_path,
              "lib",
              app <> "-" <> vsn,
              "ebin",
              app <> ".app"
            ])

          [app_file_path | app_files]
        else
          app_files
        end
    end)
  end

  defp target_priv_dirs(applications, target_release_path) do
    Enum.reduce(applications, [], fn
      {app, vsn, path}, priv_dirs ->
        host_priv_dir = Path.join(path, "priv")

        if File.dir?(host_priv_dir) and not_empty_dir(host_priv_dir) do
          priv_dir = Path.join([target_release_path, "lib", app <> "-" <> to_string(vsn), "priv"])

          [priv_dir | priv_dirs]
        else
          priv_dirs
        end
    end)
  end

  defp rel_paths(paths) do
    paths
    |> Enum.map(&to_string/1)
    |> Enum.map(&Path.split/1)
    |> Enum.map(fn [_root | path] ->
      Path.join(path)
    end)
  end

  defp release_opts do
    [
      quiet: true,
      include_executables_for: [],
      include_erts: &Nerves.Release.erts/0,
      boot_scripts: []
    ]
  end

  defp not_empty_dir(dir) do
    File.ls(dir) != {:ok, []}
  end

  defp normalize_applications(applications) do
    Enum.map(applications, fn
      %{name: app, vsn: vsn, path: path} ->
        {to_string(app), to_string(vsn), Path.expand(to_string(path))}

      {app, opts} ->
        {to_string(app), to_string(opts[:vsn]), Path.expand(to_string(opts[:path]))}
    end)
  end

  defp expand_target_path(target_release_path, path) do
    Path.join(["/", target_release_path, path])
    |> Path.expand(target_release_path)
    |> String.trim_leading("/")
  end
end
