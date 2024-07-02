defmodule Nerves.Release.BootOrderer do
  @moduledoc """
  This module orders load and start operations in release boot scripts

  By default, release boot scripts are ordered based on dependencies by
  libraries.  E.g., libraries that you depend on are loaded and started before
  you are. This is highly desirable, but it's helpful to do better for Nerves.

  Here are some things that this does:

  1. When dependency relationships don't specify an ordering, order is
     alphabetic so that scripts are deterministic between rebuilds.
  2. The `:logger` and `:sasl` applications are initialized as early as
     possible to avoid being blind to logs just due to having a library
     initialized too early.
  3. The `:iex` application is initialized as late as possible, since if you're
     measuring boot time, showing an IEx prompt is likely the least interesting
     code to have to wait for.

  All of these are configurable too via the `:init` and `:last` configuration
  options.

  The second major thing this module does is that it changes the application
  start type for most applications. The default application start type of
  `:permanent` causes the Erlang VM to reboot when the application doesn't
  start successfully. This is really hard to debug. It's much easier to debug
  `:temporary` since you're still in the VM. To support this, as many
  applications are marked `:temporary` as possible.
  """

  # These applications should cause a reboot if they fail
  @permanent_applications [
    :runtime_tools,
    :kernel,
    :stdlib,
    :compiler,
    :elixir,
    :iex,
    :crypto,
    :logger,
    :sasl
  ]

  @doc """
  Build the nerves boot script
  """
  @spec init(Mix.Release.t()) :: Mix.Release.t()
  def init(%Mix.Release{} = release) do
    opts = options(release)

    init_apps = [:logger, :sasl] ++ Access.get(opts, :init, [])
    last_apps = Access.get(opts, :last, [:iex])
    extra_deps = Access.get(opts, :extra_dependencies, [])

    # Validate arguments
    Enum.each(init_apps, &check_app(&1, release.applications))
    Enum.each(last_apps, &check_app(&1, release.applications))

    # Build dependency graph
    sorted_apps =
      :digraph.new([:private, :acyclic])
      |> add_release_apps(release.applications)
      |> add_extra_dependencies(extra_deps)
      |> add_init_dependencies(init_apps)
      |> add_last_dependencies(last_apps)
      |> alphabetize_dependencies()
      |> :digraph_utils.topsort()
      |> Enum.reverse()

    apps_with_modes = assign_modes_to_apps(release)

    start_apps =
      for app <- sorted_apps do
        {app, apps_with_modes[app]}
      end

    # Create a shoehorn bootscript as well since there are so many references
    # to it.  Squashfs should see that the two scripts are the same and remove
    # the duplication.
    new_boot_scripts =
      release.boot_scripts
      |> Map.put(:nerves, start_apps)
      |> Map.put(:shoehorn, start_apps)

    %{release | boot_scripts: new_boot_scripts}
  end

  defp options(release) do
    # Pull options from the old shoehorn config, but prefer nerves ones
    legacy_config = Application.get_all_env(:shoehorn)
    nerves_config = Application.get_all_env(:nerves)
    config = Keyword.merge(legacy_config, nerves_config)

    options = release.options[:nerves] || release.options[:shoehorn] || []

    Keyword.merge(config, options)
  end

  defp assign_modes_to_apps(release) do
    # Mix release doesn't pass the user's application modes, but they can
    # be derived from the start script if it exists.
    case release.boot_scripts[:start] do
      nil ->
        release.applications
        |> Enum.map(fn {app, _info} -> {app, :permanent} end)
        |> Enum.map(&update_start_mode/1)

      app_modes ->
        Enum.map(app_modes, &update_start_mode/1)
    end
  end

  defp update_start_mode({app, mode}) do
    new_mode =
      case mode do
        :permanent ->
          # Should non-application libraries be started as permanent?
          if app in @permanent_applications, do: :permanent, else: :temporary

        other_mode ->
          other_mode
      end

    {app, new_mode}
  end

  defp add_release_apps(dep_graph, release_apps) do
    Enum.each(release_apps, fn {app, _info} -> :digraph.add_vertex(dep_graph, app) end)

    Enum.each(release_apps, fn {app, info} ->
      Enum.each(info[:applications], &:digraph.add_edge(dep_graph, app, &1, :release))
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
        raise RuntimeError, "Unknown application #{inspect(v)}"

      {:error, {:bad_edge, [_, _]}} ->
        # Edge already exists, so this is ok
        :ok

      {:error, {:bad_edge, _path}} ->
        raise RuntimeError,
              "Cycle detected when adding the #{inspect(dep)} dependencies to #{inspect(app)}"

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

  # defp inspect_graph(dep_graph) do
  #   Enum.each(:digraph.edges(dep_graph), fn e ->
  #     {_, v1, v2, label} = :digraph.edge(dep_graph, e)
  #     IO.puts("#{v1} -> #{v2} (#{label})")
  #   end)
  # end

  defp order_dependencies(_, []), do: :ok

  defp order_dependencies(dep_graph, [dep | rest]) do
    Enum.each(rest, &:digraph.add_edge(dep_graph, dep, &1, :alpha))
    order_dependencies(dep_graph, rest)
  end

  defp check_app(app, applications) when is_atom(app) do
    applications[app] != nil or raise RuntimeError, "#{app} is not a known OTP application"
  end

  defp check_app({_, _, _} = mfa, _applications) do
    raise RuntimeError, """
    #{inspect(mfa)} is no longer supported in `:init` option.

    To fix, move this function call to an appropriate `Application.start/2`.
    Depending on what this is supposed to do, other ways may be possible too.

    Long story: While it looks like the `:init` list would be processed in
    order with the function calls in between `Application.start/1` calls, there
    really was no guarantee. Application dependencies and how applications are
    sorted in dependency lists take precedence over the `:init` list order.
    There's also a technical reason in that bare functions aren't allowed to be
    listed in application start lists for creating the release. While the
    latter could be fixed, not knowing when a function is called in relation to
    other application starts leads to confusing issues and it seems best to
    find another way when you want to do this.
    """
  end

  defp check_app(other, _applications) do
    raise RuntimeError, """
    The Shoehorn `:init` option only supports atoms. #{inspect(other)}
    """
  end
end
