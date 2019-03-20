defmodule Nerves do
  use Mix.Releases.Plugin

  alias Mix.Releases.{Release, Shell}

  # No leading '/' here since this is passed to mksquashfs and it
  # doesn't like the leading slash.
  @target_release_path "srv/erlang"

  def before_assembly(release, _opts) do
    if nerves_env_loaded?() do
      vm_args = Map.get(release.profile, :vm_args) || "rel/vm.args"
      plugins = order_plugins(release.profile.plugins)

      profile =
        release.profile
        |> Map.put(:dev_mode, false)
        |> Map.put(:include_src, false)
        |> Map.put(:include_erts, System.get_env("ERL_LIB_DIR"))
        |> Map.put(:vm_args, vm_args)
        |> Map.put(:plugins, plugins)

      %{release | profile: profile}
    else
      release
    end
  end

  # After assembling the release, generate a file that sets the filesystem order
  # priority
  def after_assembly(%Release{} = release, _opts) do
    if nerves_env_loaded?() do
      bootfile_name = Application.get_env(:nerves, :firmware)[:bootfile] || "shoehorn.boot"

      bootfile_path =
        Path.join([release.profile.output_dir, "releases", release.version, bootfile_name])

      case File.read(bootfile_path) do
        {:ok, bootfile} ->
          write_rootfs_priorities(release, bootfile)

        _ ->
          Shell.warn("""
            Unable to load bootfile: #{inspect(bootfile_path)}
            Skipping rootfs priority file generation
          """)
      end
    end

    release
  end

  def before_package(%Release{} = release, _opts) do
    release
  end

  def after_package(%Release{} = release, _opts) do
    release
  end

  def after_cleanup(_args, _opts) do
    :noop
  end

  def version, do: unquote(Mix.Project.config()[:version])
  def elixir_version, do: unquote(System.version())

  def nerves_env_loaded? do
    System.get_env("NERVES_ENV_BOOTSTRAP") != nil
  end

  defp write_rootfs_priorities(release, bootfile) do
    host_release_path = release.profile.output_dir
    target_release_path = @target_release_path
    applications = release.applications

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
    File.mkdir_p(build_path)

    Path.join(build_path, "rootfs.priorities")
    |> File.write(priorities)
  end

  defp rel_paths(paths) do
    paths
    |> Enum.map(&to_string/1)
    |> Enum.map(&Path.split/1)
    |> Enum.map(fn [_root | path] ->
      Path.join(path)
    end)
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
                  path = Path.join([path, filename])

                  if File.exists?(Path.join([host_release_path, path])) do
                    [Path.join([target_release_path, path]) | loaded]
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
    Enum.reduce(applications, [], fn %{name: name, vsn: vsn, path: path}, app_files ->
      app_name = to_string(name)
      host_path = Path.join([path, "ebin", app_name <> ".app"])

      if File.exists?(host_path) do
        app_file_path =
          Path.join([
            target_release_path,
            "lib",
            app_name <> "-" <> to_string(vsn),
            "ebin",
            app_name <> ".app"
          ])

        [app_file_path | app_files]
      else
        app_files
      end
    end)
  end

  defp target_priv_dirs(applications, target_release_path) do
    Enum.reduce(applications, [], fn %{name: name, vsn: vsn, path: path}, priv_dirs ->
      app_name = to_string(name)
      host_priv_dir = Path.join(path, "priv")

      if File.dir?(host_priv_dir) do
        priv_dir =
          Path.join([target_release_path, "lib", app_name <> "-" <> to_string(vsn), "priv"])

        [priv_dir | priv_dirs]
      else
        priv_dirs
      end
    end)
  end

  # Make sure the Shoehorn plugin executes before the Nerves plugin
  defp order_plugins(plugins) do
    if Enum.find(plugins, &shoehorn_plugin/1) != nil do
      shoehorn_idx = Enum.find_index(plugins, &shoehorn_plugin/1)
      nerves_idx = Enum.find_index(plugins, &nerves_plugin/1)

      if nerves_idx < shoehorn_idx do
        plugins
        |> List.replace_at(nerves_idx, Enum.find(plugins, &shoehorn_plugin/1))
        |> List.replace_at(shoehorn_idx, Enum.find(plugins, &nerves_plugin/1))
      else
        plugins
      end
    else
      plugins
    end
  end

  defp shoehorn_plugin({Shoehorn, _}), do: true
  defp shoehorn_plugin({_, _}), do: false

  defp nerves_plugin({Nerves, _}), do: true
  defp nerves_plugin({_, _}), do: false
end
