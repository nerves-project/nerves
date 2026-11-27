# SPDX-FileCopyrightText: 2026 Lars Wikman
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.BuildAction.RemoveMixTasks do
  @moduledoc """
  Release step that removes Mix tasks from the firmware

  Many libraries ship Mix tasks (`Mix.Tasks.*` modules) alongside their runtime
  code. Mix isn't available on Nerves devices, so those modules can't run
  there. They only take up space and, when the Erlang VM is run in embedded
  mode, time at boot since every module that's listed in the boot script gets
  loaded.

  This build action runs after the OTP release has been assembled. For every
  application in the release, it:

  1. Deletes the `.beam` files of all modules whose name starts with
     `Mix.Tasks.`
  2. Removes those modules from the application's `.app` file
  3. Removes those modules from every boot script (`.boot` and `.script`) in
     the release so that the Erlang VM doesn't try to load them

  The second and third steps are important. In embedded mode, the Erlang VM
  loads every module that the boot script lists and fails to boot if one is
  missing.

  ## Configuration via application environment

  The action is run by default for all firmware builds. Configure it in your
  project's `config/target.exs` using the `:remove_mix_tasks` key.

  To keep all Mix tasks in the firmware:

  ```
  config :nerves, remove_mix_tasks: false
  ```

  To keep the Mix tasks of select OTP applications:

  ```
  config :nerves, remove_mix_tasks: [exclude: [:mix, :my_library]]
  ```

  ## Options

    * `:enabled` - set to `false` to skip this action. Defaults to `true`.

    * `:exclude` - a list of OTP applications to leave untouched. Defaults to
      `[:mix]`. The `:mix` application is only part of a release when a project
      explicitly asks for it since it wants to use Mix on the device. Mix is of
      little use without its tasks, so it's left alone unless you override
      this option.
  """

  use Nerves.BuildAction

  @mix_task_prefix "Elixir.Mix.Tasks."

  @doc """
  Remove Mix tasks from the assembled release

  The modules are removed from the release directory, the `.app` files and the
  boot scripts. The `:modules` lists in the returned release's applications
  are updated to match.
  """
  @impl Nerves.BuildAction
  def post_assemble_steps(%Nerves.BuildPlan{} = _build_plan, %Mix.Release{} = release, opts) do
    opts = merge_opts(opts)

    if opts[:enabled] do
      remove_mix_tasks(release, opts[:exclude])
    else
      release
    end
  end

  defp merge_opts(opts) do
    app_env_opts =
      case Application.get_env(:nerves, :remove_mix_tasks, true) do
        enabled when is_boolean(enabled) ->
          [enabled: enabled]

        app_env when is_list(app_env) ->
          app_env

        other ->
          Mix.raise("""
          Expecting the :nerves, :remove_mix_tasks configuration to be a boolean or a keyword list. Got: #{inspect(other)}
          """)
      end

    [enabled: true, exclude: [:mix]]
    |> Keyword.merge(app_env_opts)
    |> Keyword.merge(opts)
  end

  defp remove_mix_tasks(release, exclude) do
    if not File.dir?(Path.join(release.path, "releases")) do
      Mix.raise("Expecting '#{release.path}' to contain an Erlang/OTP release")
    end

    removed =
      Path.wildcard("#{release.path}/lib/*/ebin")
      |> Enum.flat_map(&remove_from_ebin(&1, exclude))
      |> MapSet.new()

    if MapSet.size(removed) > 0 do
      update_boot_scripts!(release.path, removed)
      update_release(release, removed)
    else
      release
    end
  end

  # Returns the list of modules that were removed
  defp remove_from_ebin(ebin, exclude) do
    case Path.wildcard("#{ebin}/*.app") do
      [app_path] ->
        if app_from_path(app_path) in exclude do
          []
        else
          remove_from_app(ebin, app_path)
        end

      _ ->
        # Not an OTP application. No boot script references it, so leave it.
        []
    end
  end

  defp app_from_path(app_path) do
    app_path |> Path.basename(".app") |> String.to_atom()
  end

  defp remove_from_app(ebin, app_path) do
    {:application, app, properties} = consult_one!(app_path)
    modules = Keyword.get(properties, :modules, [])

    beam_paths = Path.wildcard("#{ebin}/#{@mix_task_prefix}*.beam")
    on_disk = Enum.map(beam_paths, &(&1 |> Path.basename(".beam") |> String.to_atom()))
    listed = Enum.filter(modules, &mix_task?/1)

    Enum.each(beam_paths, &File.rm!/1)

    if listed != [] do
      new_properties = Keyword.replace!(properties, :modules, modules -- listed)
      write_term!(app_path, {:application, app, new_properties})
    end

    Enum.uniq(on_disk ++ listed)
  end

  defp mix_task?(module) do
    module |> Atom.to_string() |> String.starts_with?(@mix_task_prefix)
  end

  defp update_boot_scripts!(release_path, removed) do
    Path.wildcard("#{release_path}/releases/**/*.boot")
    |> Enum.each(fn path ->
      script = path |> File.read!() |> :erlang.binary_to_term()
      File.write!(path, :erlang.term_to_binary(filter_script(script, removed)))
    end)

    Path.wildcard("#{release_path}/releases/**/*.script")
    |> Enum.each(fn path ->
      script = consult_one!(path)
      write_term!(path, filter_script(script, removed))
    end)
  end

  defp filter_script({:script, rel_info, instructions}, removed) do
    {:script, rel_info, Enum.map(instructions, &filter_instruction(&1, removed))}
  end

  defp filter_instruction({:primLoad, modules}, removed) do
    {:primLoad, reject_removed(modules, removed)}
  end

  defp filter_instruction(
         {:apply, {:application, :load, [{:application, app, properties}]}},
         removed
       ) do
    new_properties =
      case Keyword.fetch(properties, :modules) do
        {:ok, modules} -> Keyword.replace!(properties, :modules, reject_removed(modules, removed))
        :error -> properties
      end

    {:apply, {:application, :load, [{:application, app, new_properties}]}}
  end

  defp filter_instruction(other, _removed), do: other

  defp reject_removed(modules, removed) do
    Enum.reject(modules, &MapSet.member?(removed, &1))
  end

  defp update_release(release, removed) do
    new_applications =
      Map.new(release.applications, fn {app, properties} ->
        case Keyword.fetch(properties, :modules) do
          {:ok, modules} ->
            {app, Keyword.replace!(properties, :modules, reject_removed(modules, removed))}

          :error ->
            {app, properties}
        end
      end)

    %{release | applications: new_applications}
  end

  defp consult_one!(path) do
    case :file.consult(path) do
      {:ok, [term]} ->
        term

      {:ok, _terms} ->
        Mix.raise("Expecting '#{path}' to contain one Erlang term")

      {:error, reason} ->
        Mix.raise("Could not read '#{path}': #{:file.format_error(reason)}")
    end
  end

  defp write_term!(path, term) do
    contents = :io_lib.format("%% coding: utf-8~n~tp.~n", [term])
    File.write!(path, :unicode.characters_to_binary(contents))
  end
end
