# SPDX-FileCopyrightText: 2026 Tom Hoenderdos
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Precompiled.Match do
  @moduledoc """
  The key: when a precompiled build may stand in for a local compile. Pure
  functions over the project's lock, the manifest entry and the toolchain,
  so every rule is testable without a network or a build.
  """

  @tooling_prefixes ["nerves_system_", "nerves_toolchain_"]
  @tooling_names ["nerves", "nerves_system_br", "nerves_bootstrap"]

  @type ctx :: %{
          name: String.t(),
          version: String.t(),
          lock_entry: tuple(),
          lock: map(),
          system: {String.t(), String.t()},
          elixir: String.t(),
          otp: String.t(),
          config: (String.t(), [String.t()] -> {:ok, term()} | :error)
        }

  @spec candidate?(atom(), map(), [atom()]) :: boolean()
  def candidate?(dep, lock, except) do
    name = Atom.to_string(dep)

    with true <- Map.has_key?(lock, dep),
         true <- hex?(lock[dep]),
         false <- dep in except,
         false <- tooling?(name),
         false <- dep in nerves_children(lock) do
      true
    else
      _ -> false
    end
  end

  @spec tooling?(String.t()) :: boolean()
  def tooling?(name),
    do: name in @tooling_names or Enum.any?(@tooling_prefixes, &String.starts_with?(name, &1))

  @doc "Lock-closure children of `nerves`; nerves_bootstrap recompiles them whenever it compiles nerves."
  @spec nerves_children(map()) :: [atom()]
  def nerves_children(lock) do
    closure([:nerves], lock, MapSet.new()) |> MapSet.delete(:nerves) |> MapSet.to_list()
  end

  defp closure([], _lock, seen), do: seen

  defp closure([app | rest], lock, seen) do
    if MapSet.member?(seen, app) do
      closure(rest, lock, seen)
    else
      closure(children(lock[app], lock) ++ rest, lock, MapSet.put(seen, app))
    end
  end

  defp children({:hex, _, _, _, _, deps, _, _}, lock),
    do: for({d, _, _} <- deps, Map.has_key?(lock, d), do: d)

  defp children(_, _), do: []

  defp hex?({:hex, _, _, _, _, _, _, outer}) when is_binary(outer), do: true
  defp hex?(_), do: false

  @spec select(map(), ctx()) :: {:ok, map(), String.t()} | {:miss, String.t()}
  def select(manifest, ctx) do
    {system, system_version} = ctx.system
    systems = get_in(manifest, ["versions", ctx.version]) || %{}

    if systems == %{} do
      {:miss, "not built for #{ctx.version}"}
    else
      select_entry(systems["pure_elixir"], systems[system], system, system_version, ctx)
    end
  end

  # A pure_elixir entry is the host build of a package whose whole closure
  # is pure Elixir, the same for every system, so it is tried first; the
  # system entry is the fallback, and its reason wins on a double miss.
  defp select_entry(pe, sys, system, system_version, ctx) do
    pe_result = if pe, do: check(pe, "pure_elixir", ctx)

    cond do
      match?({:ok, _, _}, pe_result) -> pe_result
      sys -> check(sys, system, ctx)
      pe_result -> pe_result
      true -> {:miss, "not built for #{system} #{system_version}"}
    end
  end

  defp check(entry, system_key, ctx) do
    build = entry["build"] || %{}
    {_, _system_version} = ctx.system
    {:hex, _, _, _, _, _, _, outer} = ctx.lock_entry

    with :ok <- eq(build["elixir"], ctx.elixir, &"built with Elixir #{&1}, running #{&2}"),
         :ok <- eq(build["otp"], ctx.otp, &"built with OTP #{&1}, running #{&2}"),
         :ok <- system_ok(system_key, build["system_version"], ctx.system),
         :ok <- present(build, "package_checksum"),
         :ok <-
           eq(build["package_checksum"], outer, fn _, _ ->
             "package checksum differs from mix.lock"
           end),
         :ok <- present(build, "deps"),
         :ok <- deps_ok(build["deps"], ctx.lock),
         :ok <- declared_deps_ok(ctx.lock_entry, build["deps"], ctx.lock),
         :ok <- present(build, "compile_env"),
         :ok <- compile_env_ok(build["compile_env"], ctx.config) do
      {:ok, entry, system_key}
    end
  catch
    _, _ -> {:miss, "malformed entry"}
  end

  defp eq(a, b, _fmt) when a == b, do: :ok
  defp eq(a, b, fmt), do: {:miss, fmt.(a, b)}

  defp system_ok("pure_elixir", _, _), do: :ok
  defp system_ok(_key, built, {_system, project}) when built == project, do: :ok

  defp system_ok(_key, built, {system, project}),
    do: {:miss, "built for #{system} #{built}, project has #{project}"}

  @field_names %{
    "package_checksum" => "package_checksum",
    "deps" => "deps lock",
    "compile_env" => "compile_env"
  }

  defp present(build, key) do
    case Map.fetch(build, key) do
      {:ok, v} when not is_nil(v) -> :ok
      _ -> {:miss, "build predates #{@field_names[key]}"}
    end
  end

  defp deps_ok(deps, lock) do
    Enum.reduce_while(deps, :ok, fn {name, %{"version" => v, "checksum" => c}}, :ok ->
      atom_name =
        try do
          String.to_existing_atom(name)
        rescue
          ArgumentError ->
            nil
        end

      case lock[atom_name] do
        {:hex, _, ^v, _, _, _, _, ^c} ->
          {:cont, :ok}

        {:hex, _, ^v, _, _, _, _, _} ->
          {:halt, {:miss, "built against #{name} #{v} with another checksum"}}

        {:hex, _, lv, _, _, _, _, _} ->
          {:halt, {:miss, "built against #{name} #{v}, lock has #{lv}"}}

        _ ->
          {:halt, {:miss, "built against #{name} #{v}, not in lock"}}
      end
    end)
  end

  # Every dep the package declares (optional ones included) that this
  # project locks must have been in the build: an optional dep changes
  # compile-time branches (`Code.ensure_loaded?/1`), so a build made without
  # it is not the build Mix would make here. Versions and checksums of the
  # ones present were already checked by `deps_ok/2`.
  defp declared_deps_ok({:hex, _, _, _, _, declared, _, _}, built, lock) do
    Enum.reduce_while(declared, :ok, fn {name, _req, _opts}, :ok ->
      case lock[name] do
        nil ->
          {:cont, :ok}

        entry ->
          if Map.has_key?(built, Atom.to_string(name)),
            do: {:cont, :ok},
            else: {:halt, {:miss, "built without #{name}, lock has #{locked_version(entry)}"}}
      end
    end)
  end

  defp locked_version({:hex, _, v, _, _, _, _, _}), do: v
  defp locked_version(_), do: "a non-Hex source"

  @spec compile_env_from_app(Path.t()) :: [map()] | nil
  def compile_env_from_app(app_path) do
    case :file.consult(String.to_charlist(app_path)) do
      {:ok, [{:application, _app, props}]} ->
        for {app, path, value} <- Keyword.get(props, :compile_env, []) do
          %{
            "app" => Atom.to_string(app),
            "path" => Enum.map(List.wrap(path), &to_string/1),
            "value" => Base.url_encode64(:erlang.term_to_binary(value), padding: false)
          }
        end

      _ ->
        nil
    end
  end

  @spec compile_env_ok([map()], (String.t(), [String.t()] -> {:ok, term()} | :error)) ::
          :ok | {:miss, String.t()}
  def compile_env_ok(items, config) do
    mismatches =
      for %{"app" => app, "path" => path, "value" => value} <- items,
          :erlang.binary_to_term(Base.url_decode64!(value, padding: false), [:safe]) !=
            config.(app, path),
          do: "#{app} [:#{Enum.join(path, ", :")}]"

    if mismatches == [],
      do: :ok,
      else: {:miss, "compile_env differs: " <> Enum.join(mismatches, ", ")}
  end
end
