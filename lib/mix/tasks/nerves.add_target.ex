# SPDX-FileCopyrightText: 2026 Lars Wikman
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.AddTarget.Docs do
  @moduledoc false

  @spec short_doc() :: String.t()
  def short_doc() do
    "Adds targets to a Nerves project"
  end

  @spec example() :: String.t()
  def example() do
    "mix nerves.add_target rpi4"
  end

  @spec long_doc() :: String.t()
  def long_doc() do
    """
    #{short_doc()}

    This adds the Nerves system for each target to the dependencies in
    `mix.exs` and adds the target to the `@all_targets` module attribute.
    Nothing else in the project is changed. Targets that the project already
    has are left alone.

    The system dependency is written to `mix.exs` with its `:targets` option,
    so it isn't fetched or compiled for the host. Run `mix deps.get` with
    `MIX_TARGET` set to the new target afterwards.

    ## Examples

    Add an official target by name. More than one can be passed:

    ```bash
    #{example()}
    mix nerves.add_target rpi5 rpi0_2
    ```

    The official targets are: #{official_targets()}

    For any other system, say where it comes from after the target name. This
    is the same package syntax that `mix igniter.install` uses:

    ```bash
    # GitHub, optionally with a branch, tag or commit
    mix nerves.add_target my_board nerves_system_my_board@github:me/nerves_system_my_board
    mix nerves.add_target my_board nerves_system_my_board@github:me/nerves_system_my_board@v1.2.0

    # Any Git repository
    mix nerves.add_target my_board nerves_system_my_board@git:https://example.com/my_board.git

    # A directory
    mix nerves.add_target my_board nerves_system_my_board@path:../nerves_system_my_board

    # Hex, with or without a version
    mix nerves.add_target my_board nerves_system_my_board@1.2.0
    mix nerves.add_target my_board nerves_system_my_board
    ```

    The target name can be left out when the package is called
    `nerves_system_<target>`:

    ```bash
    mix nerves.add_target nerves_system_my_board@github:me/nerves_system_my_board
    ```
    """
  end

  if Code.ensure_loaded?(Igniter) do
    defp official_targets() do
      Nerves.Igniter.official_systems()
      |> Map.keys()
      |> Enum.sort()
      |> Enum.map_join(", ", &"`#{&1}`")
    end
  else
    defp official_targets(), do: "(install `igniter` to see the list)"
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Nerves.AddTarget do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :nerves,
        example: __MODULE__.Docs.example(),
        positional: [targets: [rest: true]]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      args = split_args(igniter.args.positional[:targets])

      if Nerves.Igniter.nerves_project?(igniter) do
        # Problems become Igniter issues, so nothing is written unless
        # everything that was passed can be added.
        args |> pair_up() |> Enum.reduce(igniter, &add/2)
      else
        Igniter.add_issue(igniter, """
        nerves.add_target: this isn't a Nerves project yet. Run this first:

            mix igniter.install nerves
        """)
      end
    end

    defp add({:official, target}, igniter) do
      if valid_target?(target) do
        # Unknown names are turned into atoms as well. They end up in an error
        # message and nowhere else.
        Nerves.Igniter.add_target(igniter, String.to_atom(target))
      else
        invalid_target(igniter, target)
      end
    end

    defp add({:system, nil, spec}, igniter) do
      case spec |> package_name() |> String.split("nerves_system_", parts: 2) do
        ["", target] when target != "" ->
          add({:system, target, spec}, igniter)

        _ ->
          Igniter.add_issue(igniter, """
          nerves.add_target: can't tell which target #{spec} is for since the \
          package isn't called nerves_system_<target>. Put the target name before it:

              mix nerves.add_target my_target #{spec}
          """)
      end
    end

    defp add({:system, target, spec}, igniter) do
      if valid_target?(target) do
        {app, opts} = system_dep(spec)
        Nerves.Igniter.add_system(igniter, app, String.to_atom(target), opts)
      else
        invalid_target(igniter, target)
      end
    end

    defp invalid_target(igniter, target) do
      Igniter.add_issue(igniter, """
      nerves.add_target: #{inspect(target)} isn't a valid target name. Target \
      names start with a lowercase letter and only have lowercase letters, \
      digits and underscores.
      """)
    end

    defp valid_target?(target), do: target =~ ~r/^[a-z][a-z0-9_]*$/

    # Targets can be separated with commas like for `mix nerves.install
    # --target`. Packages can't since their paths and URLs may have commas.
    defp split_args(args) do
      args
      |> List.wrap()
      |> Enum.flat_map(fn arg ->
        if package?(arg), do: [arg], else: String.split(arg, ",", trim: true)
      end)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()
    end

    defp package?(arg) do
      String.contains?(arg, "@") or String.starts_with?(package_name(arg), "nerves_system_")
    end

    # "org/repo.package@source" -> "package"
    defp package_name(spec) do
      spec
      |> String.split("@", parts: 2)
      |> hd()
      |> String.split("/")
      |> List.last()
      |> String.split(".")
      |> List.last()
    end

    # A package is for the target name right before it if there is one
    defp pair_up([]), do: []

    defp pair_up([first, second | rest]) do
      cond do
        package?(first) -> [{:system, nil, first} | pair_up([second | rest])]
        package?(second) -> [{:system, first, second} | pair_up(rest)]
        true -> [{:official, first} | pair_up([second | rest])]
      end
    end

    defp pair_up([last]) do
      if package?(last), do: [{:system, nil, last}], else: [{:official, last}]
    end

    # Uses Igniter's parser so that the syntax stays the same as for `mix
    # igniter.install`. A package without a version or source is looked up on
    # Hex. Igniter adds `override: true` to Git and path dependencies, which
    # isn't wanted for a system.
    defp system_dep(spec) do
      case Igniter.Project.Deps.determine_dep_type_and_version!(spec) do
        {app, requirement} when is_binary(requirement) ->
          {app, requirement: requirement}

        {app, source} when is_list(source) ->
          {app, source: Keyword.delete(source, :override)}

        {app, requirement, source} ->
          {app, requirement: requirement, source: Keyword.delete(source, :override)}
      end
    end
  end
else
  defmodule Mix.Tasks.Nerves.AddTarget do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'nerves.add_target' requires igniter. Please install igniter and try again.

      For more information, see: https://igniter.hexdocs.pm/readme.html#installation
      """)

      exit({:shutdown, 1})
    end
  end
end
