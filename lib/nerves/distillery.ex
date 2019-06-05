if Code.ensure_loaded?(Distillery.Releases.Plugin) do
  defmodule Nerves.Distillery do
    use Distillery.Releases.Plugin

    alias Distillery.Releases.{Release, Shell}

    def before_assembly(release, _opts) do
      if Nerves.Env.loaded?() do
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
      if Nerves.Env.loaded?() do
        bootfile_name = Application.get_env(:nerves, :firmware)[:bootfile] || "shoehorn.boot"

        bootfile_path =
          Path.join([release.profile.output_dir, "releases", release.version, bootfile_name])

        case File.read(bootfile_path) do
          {:ok, bootfile} ->
            Nerves.Release.write_rootfs_priorities(
              release.applications,
              release.profile.output_dir,
              bootfile
            )

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
end
