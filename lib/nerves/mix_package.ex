# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.MixPackage do
  # This module contains a struct and utilities for dealing with Mix packages.
  # It has similarities to %Mix.Dep{}, but %Mix.Dep{} is a private API and
  # isn't used for top level package. All use of %Mix.Dep{} is here to contain
  # it in one place.

  @moduledoc false

  defstruct([:app, :config, :dest, :deps])
  @type t() :: %__MODULE__{app: atom(), config: map(), dest: String.t(), deps: [atom()]}

  @type app_tree() :: %{atom() => [atom()]}

  @doc """
  Return nerves-aware packages in the order they should be compiled

  If package A depends on package B, then B will be in the list before A.
  """
  @spec nerves_packages_in_compile_order() :: [t()]
  def nerves_packages_in_compile_order() do
    all_packages()
    |> Enum.filter(&nerves_aware_package?/1)
    |> remove_extraneous_deps()
    |> top_sort()
    |> Enum.reverse()
  end

  @doc """
  Convert the Mix.Project dependency graph to point to Nerves.MixProject structs

  This should be the only function that needs to query Mix.Project for package
  metadata.
  """
  @spec all_packages() :: [t()]
  def all_packages() do
    # By default, the deps_tree only has the immediate dependencies. Use
    # the transitive closure to let us trim uninteresting dependencies from the
    # tree easily.
    deps_tree = Mix.Project.deps_tree() |> transitive_closure()
    deps_paths = Mix.Project.deps_paths()
    all_deps = Map.keys(deps_tree)

    config = Mix.Project.config()

    top_package =
      %__MODULE__{
        app: config[:app],
        config: config,
        dest: File.cwd!(),
        deps: all_deps
      }

    [top_package | Enum.map(all_deps, &dep_to_package(&1, deps_tree, deps_paths))]
  end

  defp dep_to_package(dep, deps_tree, deps_paths) do
    dest = deps_paths[dep]
    config = Mix.Project.in_project(dep, dest, fn _ -> Mix.Project.config() end)

    %__MODULE__{
      app: dep,
      config: config,
      dest: dest,
      deps: deps_tree[dep]
    }
  end

  @doc """
  Compute the transitive closure of a package graph

  Each package in the returned graph will have dependency lists that include
  its direct dependencies and all of their dependencies.
  """
  @spec transitive_closure(app_tree()) :: app_tree()
  def transitive_closure(app_tree) do
    Map.keys(app_tree) |> Enum.map(&do_transitive_closure(app_tree, &1)) |> Map.new()
  end

  defp do_transitive_closure(app_tree, app) do
    {app, do_transitive_closure(app_tree, app, MapSet.new()) |> MapSet.to_list()}
  end

  defp do_transitive_closure(app_tree, app, acc) do
    unseen_deps = Enum.reject(app_tree[app], &MapSet.member?(acc, &1))
    new_acc = Enum.reduce(unseen_deps, acc, &MapSet.put(&2, &1))

    Enum.reduce(unseen_deps, new_acc, &do_transitive_closure(app_tree, &1, &2))
  end

  defp nerves_aware_package?(dep) do
    # :nerves for Nerves 2 packages
    # :nerves_package for Nerves 1 packages
    Keyword.has_key?(dep.config, :nerves) or Keyword.has_key?(dep.config, :nerves_package)
  end

  # Remove all dependencies that aren't in the package list. Since the
  # package list will just contains Nerves-aware packages, this gets
  # rid of the non-Nerves-aware packages.
  defp remove_extraneous_deps(packages) do
    nerves_deps = Enum.map(packages, & &1.app)

    Enum.map(packages, fn package ->
      new_deps = Enum.filter(package.deps, &(&1 in nerves_deps))
      %{package | deps: new_deps}
    end)
  end

  defp top_sort(deps) do
    originals = Map.new(deps, fn dep -> {dep.app, dep} end)
    simple_deps = Enum.map(deps, fn dep -> {dep.app, dep.deps} end)

    simple_sorted = do_top_sort(simple_deps, [])
    for {app, []} <- simple_sorted, do: originals[app]
  end

  defp do_top_sort([], acc), do: acc

  defp do_top_sort(deps, acc) do
    next = Enum.find(deps, fn dep -> elem(dep, 1) == [] end)
    {next_app, _} = next

    new_deps =
      deps
      |> List.delete(next)
      |> Enum.map(fn {k, v} -> {k, List.delete(v, next_app)} end)

    do_top_sort(new_deps, [next | acc])
  end
end
