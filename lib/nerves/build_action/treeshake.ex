# SPDX-FileCopyrightText: 2026 Nerves Project Authors
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.BuildAction.Treeshake do
  @moduledoc """
  Remove unused BEAM modules and functions using Popcorn's tree-shaker.

  Tree-shaking is disabled by default. Enable it with
  `config :nerves, treeshake: true`, or supply options:

      config :nerves,
        treeshake: [
          keep: [mod: MyApp.Console, mfa: {MyApp, :remote_callback, 2}],
          keep_applications: [:circuits_i2c]
        ]

  Tree-shaking cannot discover every dynamic call. Test the firmware on hardware,
  including recovery paths and remote console commands, before deploying it.
  Modules referenced in application configuration or named literally in
  `runtime.exs` or Elixir scripts in rootfs overlay directories are kept
  automatically, including `/etc/iex.exs`. This includes modules referenced by
  function captures in application configuration, such as `&MyApp.callback/2`.
  `keep_applications` keeps all public functions of the listed applications and
  their dependencies, in addition to the base preservation list:
  `:erts`, `:kernel`, `:stdlib`, `:compiler`, `:elixir`, `:iex`, `:logger`,
  `:crypto`, `:sasl`, `:runtime_tools`, `:ssh`, and `:nerves_runtime`.
  The base list preserves the VM's implicit entry points, interactive Elixir/IEx
  tooling, runtime tracing APIs, SSH recovery, and Nerves firmware validation
  and watchdog callbacks. Add applications whose public APIs must remain
  available from the console; the base list does not need to be repeated.

  The HTTP response parser and chunk decoder are also kept: their continuation
  tuples pass a single list argument, unlike the usual
  module-function-arguments calling convention.

  The `keep`, `drop`, `leave`, `ignore`, and `verbose` options are passed through
  to the upstream tree-shaker. `keep` accepts `mod`, `mfa`, `behaviour_impls`, and
  `referenced_modules_defining` entries. `leave` preserves a module byte-for-byte
  without keeping its dependencies; use `keep` as well when those are needed.

  Set `debug: true` to print each removed module and function during the build,
  sorted by module and function name. This is disabled by default.

  Tree-shaking runs on the assembled release before filesystem creation. Debug
  information is retained until analysis completes, then the release's original
  `strip_beams` setting is applied. Compiled dependencies and system artifacts
  are never modified. The input BEAMs must contain debug information.

  The implementation under `lib/nerves/treeshake` is vendored unchanged from
  Popcorn; this build action contains the Nerves-specific integration.
  """

  use Nerves.BuildAction

  @default_keep_applications [
    :erts,
    :kernel,
    :stdlib,
    :compiler,
    :elixir,
    :iex,
    :logger,
    :crypto,
    :sasl,
    :runtime_tools,
    :ssh,
    :nerves_runtime
  ]
  @upstream_options [:keep, :drop, :leave, :ignore, :verbose]

  @impl Nerves.BuildAction
  def pre_assemble_steps(_build_plan, release, opts) do
    config = Application.get_env(:nerves, :treeshake, false)

    case config do
      false ->
        release

      config when config == true or is_list(config) ->
        options = Keyword.merge(if(config == true, do: [], else: config), opts)
        validate_options!(options)
        strip_beams = Keyword.get(release.options, :strip_beams, true)

        release_options =
          release.options
          |> Keyword.put(:strip_beams, false)
          |> Keyword.put(:nerves_treeshake, {options, strip_beams})

        %{release | options: release_options}

      _ ->
        Mix.raise(":nerves :treeshake must be false, true, or a keyword list")
    end
  end

  @impl Nerves.BuildAction
  def post_assemble_steps(build_plan, release, _opts) do
    case Keyword.pop(release.options, :nerves_treeshake) do
      {nil, _} ->
        release

      {{options, strip_beams}, release_options} ->
        shake_release!(build_plan, release, options, strip_beams)
        %{release | options: Keyword.put(release_options, :strip_beams, strip_beams)}
    end
  end

  defp validate_options!(options) do
    unknown = Keyword.keys(options) -- [:debug, :keep_applications | @upstream_options]

    if unknown != [] do
      Mix.raise("Unknown Nerves treeshake options: #{inspect(unknown)}")
    end
  end

  defp shake_release!(build_plan, release, options, strip_beams) do
    consolidated = Path.wildcard("#{release.version_path}/consolidated/*.beam")
    beams = Path.wildcard("#{release.path}/lib/*/ebin/*.beam")
    apps = Path.wildcard("#{release.path}/lib/*/ebin/*.app")
    files = Enum.uniq_by(consolidated ++ beams ++ apps, &Path.basename/1)
    output = Path.join(release.path, ".treeshake")

    keep_applications =
      Enum.uniq(@default_keep_applications ++ Keyword.get(options, :keep_applications, []))

    # Older logger handlers don't always declare the :logger_handler behaviour.
    kept =
      [mod: :http_chunk, mod: :httpc_response, referenced_modules_defining: {:log, 2}] ++
        keep_application_modules(apps, keep_applications) ++
        configuration_modules(build_plan, apps, release.version_path, files)

    shake_options =
      options
      |> Keyword.take(@upstream_options)
      |> Keyword.update(:keep, kept, &Enum.uniq(&1 ++ kept))
      |> Keyword.merge(ebin_files: files, output_dir: output)

    Nerves.MixUtils.info("  Tree-shaking BEAM files...")

    try do
      stats = Treeshake.run(shake_options)

      for path <- consolidated ++ beams do
        shaken = Path.join(output, Path.basename(path))

        if File.exists?(shaken) do
          binary = restore_chunks!(File.read!(shaken), File.read!(path), strip_beams)
          File.write!(path, strip_beam!(binary, strip_beams))
        else
          File.rm!(path)
        end
      end

      Enum.each(apps, &update_app_modules!/1)

      Nerves.MixUtils.info(
        "  Removed #{length(stats.modules_removed)} modules and " <>
          "#{Enum.sum(Enum.map(stats.modules_shaked, fn {_, funs} -> length(funs) end))} functions"
      )

      if Keyword.get(options, :debug, false), do: print_removed(stats)
    after
      File.rm_rf!(output)
    end
  end

  defp print_removed(stats) do
    for module <- Enum.sort(stats.modules_removed) do
      Nerves.MixUtils.info("    Removed module: #{inspect(module)}")
    end

    for {module, functions} <- Enum.sort(stats.modules_shaked),
        {name, arity} <- Enum.sort(functions) do
      Nerves.MixUtils.info("    Removed function: #{inspect(module)}.#{name}/#{arity}")
    end
  end

  defp keep_application_modules(apps, keep_applications) do
    for path <- apps,
        {:application, app, attributes} = read_term!(path),
        app in keep_applications,
        module <- Keyword.get(attributes, :modules, []) do
      {:mod, module}
    end
  end

  defp configuration_modules(build_plan, apps, version_path, files) do
    modules =
      files
      |> Enum.filter(&(Path.extname(&1) == ".beam"))
      |> MapSet.new(&(&1 |> Path.basename(".beam") |> String.to_atom()))

    app_config =
      Enum.map(apps, fn path ->
        {:application, _, attributes} = read_term!(path)
        Keyword.get(attributes, :env, [])
      end)

    sys_config = Path.join(version_path, "sys.config")
    config = if File.exists?(sys_config), do: read_term!(sys_config), else: []

    script_paths =
      (build_plan.rootfs_overlays ++ List.wrap(build_plan.config[:rootfs_overlay]))
      |> Enum.flat_map(&Path.wildcard(Path.join(&1, "**/*.exs"), match_dot: true))
      |> then(&[Path.join(version_path, "runtime.exs") | &1])
      |> Enum.filter(&File.regular?/1)

    scripts = Enum.map(script_paths, &script_configuration/1)

    [config, scripts | app_config]
    |> term_atoms()
    |> Enum.filter(&MapSet.member?(modules, &1))
    |> Enum.uniq()
    |> Enum.map(&{:mod, &1})
  end

  defp script_configuration(path) do
    path
    |> File.read!()
    |> Code.string_to_quoted!(file: path)
    |> Macro.prewalk(fn
      {:__aliases__, _, parts} = node ->
        if Enum.all?(parts, &is_atom/1), do: Module.concat(parts), else: node

      node ->
        node
    end)
  end

  defp term_atoms(atom) when is_atom(atom), do: [atom]
  defp term_atoms(tuple) when is_tuple(tuple), do: tuple |> Tuple.to_list() |> term_atoms()
  defp term_atoms(list) when is_list(list), do: Enum.flat_map(list, &term_atoms/1)
  defp term_atoms(map) when is_map(map), do: map |> Map.to_list() |> term_atoms()

  defp term_atoms(fun) when is_function(fun) do
    {:module, module} = Function.info(fun, :module)
    [module]
  end

  defp term_atoms(_), do: []

  defp read_term!(path) do
    {:ok, [term]} = :file.consult(String.to_charlist(path))
    term
  end

  defp update_app_modules!(path) do
    {:application, app, attributes} = read_term!(path)

    modules =
      Enum.filter(Keyword.get(attributes, :modules, []), fn module ->
        File.exists?(Path.join(Path.dirname(path), "#{module}.beam"))
      end)

    term = {:application, app, Keyword.put(attributes, :modules, modules)}
    File.write!(path, :io_lib.format(~c"~tp.~n", [term]))
  end

  defp restore_chunks!(binary, original, _strip_beams) when binary == original, do: binary

  defp restore_chunks!(binary, original, strip_beams) do
    # Recompiling Core Erlang drops Elixir's documentation and checker metadata.
    keep = if is_list(strip_beams), do: Keyword.get(strip_beams, :keep, []), else: []
    chunks = Enum.uniq(["Docs", "ExCk" | keep]) |> Enum.map(&String.to_charlist/1)
    {:ok, {module, original_chunks}} = :beam_lib.chunks(original, chunks, [:allow_missing_chunks])
    {:ok, ^module, rewritten_chunks} = :beam_lib.all_chunks(binary)
    replacements = Enum.filter(original_chunks, fn {_, value} -> is_binary(value) end)

    merged =
      Enum.reject(rewritten_chunks, fn {name, _} -> List.keymember?(replacements, name, 0) end)

    {:ok, binary} = :beam_lib.build_module(merged ++ replacements)
    binary
  end

  defp strip_beam!(binary, false), do: binary

  defp strip_beam!(binary, options) do
    {:ok, binary} = Mix.Release.strip_beam(binary, if(options == true, do: [], else: options))
    binary
  end
end
