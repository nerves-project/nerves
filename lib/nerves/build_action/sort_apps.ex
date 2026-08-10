# SPDX-FileCopyrightText: 2019 Justin Schneck
# SPDX-FileCopyrightText: 2022 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.BuildAction.SortApps do
  @moduledoc """
  Deterministically order OTP applications in the release boot script

  This build action sorts the OTP application start
  order deterministically and allows for additional nudging of the start order to
  improve boot time. In all cases, application dependencies force an overall order.
  However, there's usually lots of room to order application starts and this
  alphabetically sorts those starts to ensure reproducibility between builds.

  To improve startup, it can be useful to push some applications to the end. For
  example, by default, `iex`'s startup is delayed as late as possible since
  interactive shell use is usually less important than bringing up WiFi.

  ## Configuration via application environment

  The `SortApps` build action is included by default derives its configuration
  from Nerves application environment via the `:application_sort` key.

  ```
  config :nerves,
    application_sort: [
      init: [:nerves_runtime, :nerves_pack],
      last: [:iex],
      extra_dependencies: {:vintage_net_wifi, [:my_special_wifi_app]}
    ]
  ```

  The options match those that could be passed directly to `SortApp` if manually
  requesting the `SortApps` build action.

  ## Options

  The following options can be set under the `:nerves` key in release options:

    * `:init` — a list of application atoms to start as early as possible
      (after their dependencies). Useful for system-level apps that should
      be available before most user apps.

    * `:last` — a list of application atoms to start as late as possible.
      Defaults to `[:iex]`.

    * `:extra_dependencies` — a keyword list of `{app, [dep_apps]}` to
      add extra dependency edges to the graph. Useful for enforcing ordering
      that isn't captured by the OTP application spec.
  """

  use Nerves.BuildAction

  @doc """
  Sort OTP applications deterministically.

  Reads `:init`, `:last`, and `:extra_dependencies` from the release's
  `:nerves` options and builds a dependency graph to produce a stable
  topological ordering. The sorted app list replaces the `:start` boot
  script.
  """
  @impl Nerves.BuildAction
  def pre_assemble_steps(%Nerves.BuildPlan{} = _build_plan, %Mix.Release{} = release, opts) do
    default_opts = [init: [], last: [:iex], extra_dependencies: []]
    app_env = Application.get_env(:nerves, :application_sort, [])
    merged_opts = default_opts |> Keyword.merge(app_env) |> Keyword.merge(opts)

    init_apps = merged_opts[:init]
    last_apps = merged_opts[:last]
    extra_deps = merged_opts[:extra_dependencies]

    # Validate arguments
    Enum.each(init_apps, &check_app(&1, release.applications))
    Enum.each(last_apps, &check_app(&1, release.applications))

    # Build dependency graph and produce sorted order
    sorted_apps =
      :digraph.new([:private, :acyclic])
      |> add_release_apps(release.applications)
      |> add_extra_dependencies(extra_deps)
      |> add_init_dependencies(init_apps)
      |> add_last_dependencies(last_apps)
      |> alphabetize_dependencies()
      |> :digraph_utils.topsort()
      |> Enum.reverse()

    # Preserve existing modes from the start boot script
    app_modes = current_app_modes(release)

    start_apps =
      for app <- sorted_apps do
        {app, Map.get(app_modes, app, :permanent)}
      end

    new_boot_scripts = Map.put(release.boot_scripts, :start, start_apps)

    %{release | boot_scripts: new_boot_scripts}
  end

  defp current_app_modes(release) do
    case release.boot_scripts[:start] do
      nil ->
        release.applications
        |> Enum.map(fn {app, _info} -> {app, :permanent} end)
        |> Map.new()

      app_modes ->
        Map.new(app_modes)
    end
  end

  # -- Graph construction ----------------------------------------------------

  defp add_release_apps(dep_graph, release_apps) do
    Enum.each(release_apps, fn {app, _info} ->
      :digraph.add_vertex(dep_graph, app)
    end)

    Enum.each(release_apps, fn {app, info} ->
      Enum.each(info[:applications] || [], &:digraph.add_edge(dep_graph, app, &1, :release))
    end)

    dep_graph
  end

  defp add_extra_dependencies(dep_graph, extra_deps) do
    Enum.each(extra_deps, fn {app, deps} ->
      Enum.each(deps, &checked_add_edge(dep_graph, app, &1))
    end)

    dep_graph
  end

  defp checked_add_edge(graph, app, dep) do
    case :digraph.add_edge(graph, app, dep, :extra) do
      {:error, {:bad_vertex, v}} ->
        raise "Unknown application #{inspect(v)}"

      {:error, {:bad_edge, [_, _]}} ->
        # Edge already exists, so this is ok
        :ok

      {:error, {:bad_edge, _path}} ->
        raise "Cycle detected when adding the #{inspect(dep)} dependency to #{inspect(app)}"

      _ ->
        :ok
    end
  end

  defp add_init_dependencies(dep_graph, init_apps) do
    # Make every non-init_app depend on the init_app unless there's a cycle
    all_apps = :digraph.vertices(dep_graph)
    non_init_apps = all_apps -- init_apps

    # Order deps in the init list
    order_dependencies(dep_graph, Enum.reverse(init_apps))

    # Try to make everything not in the init list depend on the init list
    # (cycles and dupes are automatically ignored)
    Enum.each(non_init_apps, fn non_init_app ->
      Enum.each(init_apps, &:digraph.add_edge(dep_graph, non_init_app, &1, :init))
    end)

    dep_graph
  end

  defp add_last_dependencies(dep_graph, last_apps) do
    # Make every last_app depend on all non-last_apps unless there's a cycle
    all_apps = :digraph.vertices(dep_graph)
    non_last_apps = all_apps -- last_apps

    Enum.each(last_apps, fn last_app ->
      Enum.each(non_last_apps, &:digraph.add_edge(dep_graph, last_app, &1, :last))
    end)

    dep_graph
  end

  defp alphabetize_dependencies(dep_graph) do
    # Add edges where possible to force dependencies to be sorted alphabetically
    sorted_apps = :digraph.vertices(dep_graph) |> Enum.sort(:desc)

    order_dependencies(dep_graph, sorted_apps)

    dep_graph
  end

  defp order_dependencies(_, []), do: :ok

  defp order_dependencies(dep_graph, [dep | rest]) do
    Enum.each(rest, &:digraph.add_edge(dep_graph, dep, &1, :alpha))
    order_dependencies(dep_graph, rest)
  end

  # -- Validation ------------------------------------------------------------

  defp check_app(app, applications) when is_atom(app) do
    applications[app] != nil or
      raise """
      #{inspect(app)} is not a known OTP application.

      If '#{inspect(app)}' looks right (no typos, etc.) then check that it exists
      in your project's `mix.exs` dependency list. If it exists and has a
      `:targets` option, make sure the current target, '#{Mix.target()}', is in
      the list.
      """
  end

  defp check_app(other, _applications) do
    raise """
    The Nerves :init and :last options only support atoms. Got: #{inspect(other)}
    """
  end
end
