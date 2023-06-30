# credo:disable-for-this-file
defmodule Nerves.Release do
  @moduledoc false
  # No leading '/' here since this is passed to mksquashfs and it
  # doesn't like the leading slash.
  @target_release_path "srv/erlang"

  @doc false
  @spec init(Mix.Release.t()) :: Mix.Release.t()
  def init(%{options: options} = release) do
    opts = Keyword.merge(options, release_opts())

    release = %{
      release
      | options: opts,
        steps: release.steps ++ [&Nerves.Release.finalize/1]
    }

    check_vm_args_compatibility!(release)

    _ = File.rm_rf!(release.path)

    if Code.ensure_loaded?(Shoehorn.Release) do
      apply(Shoehorn.Release, :init, [release])
    else
      release
    end
  end

  @doc false
  @spec finalize(Mix.Release.t()) :: Mix.Release.t()
  def finalize(%Mix.Release{} = release) do
    bootfile_path = Path.join([release.version_path, bootfile()])

    case File.read(bootfile_path) do
      {:ok, bootfile} ->
        _ = write_rootfs_priorities(release.applications, release.path, bootfile)
        :ok

      _ ->
        Nerves.Utils.Shell.warn("""
          Unable to load bootfile: #{inspect(bootfile_path)}
          Skipping rootfs priority file generation
        """)
    end

    release
  end

  defp bootfile() do
    Application.get_env(:nerves, :firmware)[:bootfile] || "shoehorn.boot"
  end

  @doc false
  @spec erts() :: String.t() | true | nil
  def erts() do
    if Nerves.Env.loaded?() do
      System.get_env("ERTS_DIR")
    else
      true
    end
  end

  defp write_rootfs_priorities(applications, host_release_path, bootfile) do
    applications = normalize_applications(applications)

    {:script, _, boot_script} = :erlang.binary_to_term(bootfile)

    target_beam_files = target_beam_files(boot_script, host_release_path)
    target_app_files = target_app_files(applications)
    target_priv_dirs = target_priv_dirs(applications)

    priorities =
      (target_beam_files ++ target_app_files ++ target_priv_dirs)
      |> List.flatten()
      |> Enum.zip(32_000..1_000)
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

  defp rel_paths(paths) do
    paths
    |> Enum.reverse()
    |> Enum.map(&to_string/1)
    |> Enum.map(&Path.split/1)
    |> Enum.map(fn [_root | path] ->
      Path.join(path)
    end)
  end

  defp release_opts() do
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

  defp expand_target_path(path) do
    Path.join(["/", @target_release_path, path])
    |> Path.expand(@target_release_path)
    |> String.trim_leading("/")
  end

  defp normalize_applications(applications) do
    for {app, opts} <- applications do
      {to_string(app), to_string(opts[:vsn]), Path.expand(opts[:path] || "")}
    end
  end

  @elixir_1_15_opts ["-user elixir", "-run elixir start_iex"]
  @legacy_elixir_opts ["-user Elixir.IEx.CLI"]
  defp check_vm_args_compatibility!(release) do
    Mix.shell().info([:yellow, "* [Nerves] ", :reset, "validating vm.args"])
    vm_args_path = Mix.Release.rel_templates_path(release, "vm.args.eex")

    if not File.exists?(vm_args_path) do
      Mix.raise("Missing required #{vm_args_path}")
    end

    {exclusions, inclusions} =
      if Version.match?(System.version(), ">= 1.15.0") do
        {@legacy_elixir_opts, @elixir_1_15_opts}
      else
        {@elixir_1_15_opts, @legacy_elixir_opts}
      end

    vm_args = File.read!(vm_args_path)

    errors =
      []
      |> check_vm_args_inclusions(vm_args, inclusions, vm_args_path)
      |> check_vm_args_exclusions(vm_args, exclusions, vm_args_path)

    if length(errors) > 0 do
      errs = IO.ANSI.format(errors) |> IO.chardata_to_string()

      Mix.raise("""
      Incompatible vm.args.eex

      The procedure for starting IEx changed in Elixir 1.15. The rel/vm.args.eex for
      this project starts IEx in an incompatible way for the version of Elixir you're
      using and won't work.

      To fix this, either change the version of Elixir that you're using or make the
      following changes to vm.args.eex:
      #{errs}
      """)
    else
      :ok
    end
  end

  defp check_vm_args_exclusions(errors, vm_args, exclusions, vm_args_path) do
    String.split(vm_args, "\n")
    |> Enum.with_index(1)
    |> Enum.filter(fn {line, _} -> Enum.any?(exclusions, &String.contains?(line, &1)) end)
    |> case do
      [] ->
        []

      lines ->
        [
          "\nPlease remove the following lines:\n\n",
          Enum.map(lines, fn {line, line_num} ->
            ["* ", vm_args_path, ":", to_string(line_num), ":\n  ", :red, line, "\n"]
          end)
          | errors
        ]
    end
  end

  defp check_vm_args_inclusions(errors, vm_args, inclusions, vm_args_path) do
    case Enum.reject(inclusions, &String.contains?(vm_args, &1)) do
      [] ->
        []

      lines ->
        [
          [
            "\nPlease ensure the following lines are in ",
            vm_args_path,
            ":\n",
            :green,
            Enum.map(lines, &["  ", &1, "\n"])
          ]
          | errors
        ]
    end
  end
end
