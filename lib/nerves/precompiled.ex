# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Precompiled do
  @moduledoc """
  Opt-in: install precompiled dependency builds from a signed source before
  Mix compiles them. Enabled by `config :nerves, :precompiled, source: url`.
  Every candidate dependency prints HIT, MISS or FAIL with a reason; the
  same list lands in `_build/<target>_<env>/lib/.precompiled/report.json`.
  """

  alias Nerves.BuildPlan
  alias Nerves.MixUtils
  alias Nerves.Precompiled.{Config, Fetch, Match, Trust}

  @type line :: %{
          name: String.t(),
          version: String.t(),
          status: :hit | :miss | :fail,
          detail: String.t()
        }
  @type report :: %{
          hits: non_neg_integer(),
          misses: non_neg_integer(),
          fails: non_neg_integer(),
          bytes: non_neg_integer(),
          seconds: float(),
          lines: [line()]
        }

  @spec run(keyword()) :: :disabled | {:ok, report()}
  def run(opts \\ []) do
    with %{} = config <- Config.load(),
         false <- Keyword.get(opts, :host?, Mix.target() == :host) do
      do_run(config, opts)
    else
      _ -> :disabled
    end
  end

  defp do_run(config, opts) do
    started = System.monotonic_time(:millisecond)
    lock = Keyword.get_lazy(opts, :lock, &Mix.Dep.Lock.read/0)

    build_lib =
      Keyword.get_lazy(opts, :build_lib, fn -> Path.join(Mix.Project.build_path(), "lib") end)

    system = Keyword.get_lazy(opts, :system, fn -> system_from_plan(Nerves.build_plan()) end)
    config_fun = Keyword.get(opts, :config_fun, &config_lookup/2)

    {candidates, skipped} =
      candidates(Keyword.get_lazy(opts, :deps, &mix_deps/0), lock, config.except)

    debug_skipped(skipped)

    lines = lines_for(candidates, config, lock, system, config_fun, build_lib)
    Enum.each(lines, &print/1)
    report = summarize(lines, System.monotonic_time(:millisecond) - started)
    print_summary(report, length(lines))
    write_report(build_lib, report)
    {:ok, report}
  end

  defp lines_for(candidates, config, lock, system, config_fun, build_lib) do
    case batch(config) do
      {:ok, batch} ->
        candidates
        |> Task.async_stream(&one(&1, config, batch, lock, system, config_fun, build_lib),
          max_concurrency: 8,
          timeout: :infinity,
          ordered: true
        )
        |> Enum.map(fn {:ok, line} -> line end)

      {:error, why} ->
        Enum.map(
          candidates,
          &%{
            name: Atom.to_string(&1.name),
            version: &1.version,
            status: :fail,
            detail: why,
            bytes: 0
          }
        )
    end
  end

  defp debug_skipped(skipped) do
    if System.get_env("NERVES_PRECOMPILED_DEBUG") == "1" do
      Enum.each(skipped, fn {name, why} ->
        MixUtils.info(line(%{name: name, version: "", detail: why}, "skip"))
      end)
    end
  end

  defp print_summary(report, total) do
    MixUtils.info(
      "precompiled: #{report.hits} hit, #{report.misses} miss, #{report.fails} fail of #{total} deps, " <>
        "#{mb(report.bytes)} MB, #{Float.round(report.seconds, 1)} s"
    )
  end

  defp batch(config) do
    with {:ok, root} <- Trust.load_root(config),
         {:ok, root} <- Trust.update_root(config, root, &Fetch.get_body/1) do
      Trust.fetch_batch(config, root, &Fetch.get_body/1)
    end
  end

  defp one(
         %{name: name, version: version, lock_entry: lock_entry},
         config,
         batch,
         lock,
         system,
         config_fun,
         build_lib
       ) do
    sname = Atom.to_string(name)
    base = %{name: sname, version: version, bytes: 0}

    try do
      result =
        with sha when is_binary(sha) <- batch.manifests[sname] || {:miss, "not in batch"},
             {:ok, manifest} <- Fetch.manifest(config, sname, sha),
             {:ok, entry, _system_key} <-
               Match.select(manifest, %{
                 name: sname,
                 version: version,
                 lock_entry: lock_entry,
                 lock: lock,
                 system: system || {"host", ""},
                 elixir: System.version(),
                 otp: to_string(:erlang.system_info(:otp_release)),
                 config: config_fun
               }),
             {:ok, stats} <-
               Fetch.install(config, name, entry, lock_entry, build_lib,
                 verify_app: &verify_app(&1, config_fun)
               ) do
          {:hit, stats}
        end

      line_for(base, result)
    rescue
      e ->
        %{
          name: sname,
          version: version,
          bytes: 0,
          status: :fail,
          detail: "candidate crashed: #{Exception.message(e)}"
        }
    catch
      :exit, reason ->
        %{
          name: sname,
          version: version,
          bytes: 0,
          status: :fail,
          detail: "candidate crashed: #{inspect(reason)}"
        }
    end
  end

  defp line_for(base, {:hit, %{bytes: bytes, files: files, cached: cached}}) do
    %{base | bytes: bytes}
    |> Map.merge(%{
      status: :hit,
      detail: "#{mb(bytes)} MB#{if cached == files, do: ", cached", else: ""}"
    })
  end

  defp line_for(base, {:miss, why}), do: Map.merge(base, %{status: :miss, detail: why})
  defp line_for(base, {:fail, why}), do: Map.merge(base, %{status: :fail, detail: why})

  # Rule 5, second half: the manifest said the compile_env matches; the
  # downloaded .app is the authority. A manifest that lies still cannot
  # plant a mismatched build.
  defp verify_app(app_path, config_fun) do
    case Match.compile_env_from_app(app_path) do
      nil -> {:fail, "staged .app unreadable"}
      items -> Match.compile_env_ok(items, config_fun) |> as_fail()
    end
  end

  defp as_fail(:ok), do: :ok
  defp as_fail({:miss, why}), do: {:fail, "downloaded .app: " <> why}

  defp candidates(deps, lock, except) do
    {c, s} = Enum.reduce(deps, {[], []}, &sort_candidate(&1, &2, lock, except))
    {Enum.reverse(c), Enum.reverse(s)}
  end

  defp sort_candidate(dep, {c, s}, lock, except) do
    cond do
      Match.candidate?(dep.name, lock, except) ->
        {[dep | c], s}

      dep.name in except ->
        {c, [{dep.name, "excepted"} | s]}

      Match.tooling?(Atom.to_string(dep.name)) or dep.name in Match.nerves_children(lock) ->
        {c, [{dep.name, "tooling"} | s]}

      true ->
        {c, [{dep.name, "not a hex dep"} | s]}
    end
  end

  # Dependencies Mix would compile now: status :compile or no app file, Hex SCM.
  defp mix_deps() do
    lock = Mix.Dep.Lock.read()

    for %Mix.Dep{app: app, status: status, scm: Hex.SCM} <- Mix.Dep.load_and_cache(),
        match?(:compile, status) or match?({:noappfile, _}, status),
        entry = lock[app],
        do: %{name: app, version: elem(entry, 2), lock_entry: entry}
  end

  @spec system_from_plan(Nerves.BuildPlan.t()) :: {String.t(), String.t()} | nil
  def system_from_plan(%BuildPlan{actions: actions} = plan) do
    with {_, opts} <- Enum.find(actions, &match?({Nerves.BuildAction.NervesV1System, _}, &1)),
         %{app: app, version: version} <- BuildPlan.find_package(plan, opts[:app]) do
      {Atom.to_string(app), version}
    else
      _ -> nil
    end
  end

  @spec config_lookup(String.t(), [String.t()]) :: {:ok, term()} | :error
  def config_lookup(app, [first | rest]) do
    with {:ok, app_atom} <- safe_existing_atom(app),
         {:ok, first_atom} <- safe_existing_atom(first),
         {:ok, value} <- Application.fetch_env(app_atom, first_atom) do
      Enum.reduce_while(rest, {:ok, value}, &config_lookup_step/2)
    end
  end

  defp config_lookup_step(key, {:ok, v}) do
    case safe_existing_atom(key) do
      {:ok, k} -> config_lookup_in(v, k)
      :error -> {:halt, :error}
    end
  end

  defp config_lookup_in(kw, k) when is_list(kw) do
    if Keyword.keyword?(kw) and Keyword.has_key?(kw, k),
      do: {:cont, {:ok, kw[k]}},
      else: {:halt, :error}
  end

  defp config_lookup_in(%{} = m, k) do
    if Map.has_key?(m, k), do: {:cont, {:ok, m[k]}}, else: {:halt, :error}
  end

  defp config_lookup_in(_, _), do: {:halt, :error}

  # A manifest-derived app or key that was never an atom in this VM cannot be
  # in the project's config; don't grow the atom table from untrusted input.
  defp safe_existing_atom(s) do
    {:ok, String.to_existing_atom(s)}
  rescue
    ArgumentError -> :error
  end

  defp print(%{status: :hit} = l), do: MixUtils.success(line(l, "HIT "))
  defp print(%{status: :miss} = l), do: MixUtils.warning(line(l, "MISS"))
  defp print(%{status: :fail} = l), do: MixUtils.error(line(l, "FAIL"))

  defp line(%{name: n, version: v, detail: d}, tag),
    do: "precompiled: #{n} #{v}#{pad(n, v)}  #{tag}  #{d}"

  defp pad(n, v), do: String.duplicate(" ", max(0, 34 - String.length("precompiled: #{n} #{v}")))
  defp mb(bytes), do: Float.round(bytes / 1_048_576, 1)

  defp summarize(lines, ms) do
    count = fn s -> Enum.count(lines, &(&1.status == s)) end

    %{
      hits: count.(:hit),
      misses: count.(:miss),
      fails: count.(:fail),
      bytes: Enum.sum(Enum.map(lines, & &1.bytes)),
      seconds: ms / 1000,
      lines: Enum.map(lines, &Map.delete(&1, :bytes))
    }
  end

  defp write_report(build_lib, report) do
    dir = Path.join(build_lib, ".precompiled")
    File.mkdir_p!(dir)

    json = %{
      "hits" => report.hits,
      "misses" => report.misses,
      "fails" => report.fails,
      "bytes" => report.bytes,
      "seconds" => report.seconds,
      "lines" =>
        Enum.map(
          report.lines,
          &%{
            "name" => &1.name,
            "version" => &1.version,
            "status" => Atom.to_string(&1.status),
            "detail" => &1.detail
          }
        )
    }

    final = Path.join(dir, "report.json")
    tmp = final <> ".tmp"
    File.write!(tmp, :json.encode(json))
    File.rename!(tmp, final)
  end
end
