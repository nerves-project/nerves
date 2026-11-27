# SPDX-FileCopyrightText: 2026 Lars Wikman
#
# SPDX-License-Identifier: Apache-2.0
#
if Code.ensure_loaded?(Igniter) do
  defmodule Nerves.Igniter do
    @moduledoc """
    Helpers for writing [Igniter](https://igniter.hexdocs.pm) installers for
    Nerves projects

    This module is used by `mix nerves.install`. Libraries that have
    device-specific setup can use the predicates here to decide where their
    configuration goes.

    Nerves systems are added by editing the dependency list in `mix.exs`
    directly (see `add_system/4`) rather than with `mix igniter.install
    nerves_system_<name>`. The latter would fetch and compile the system for
    the host before its `:targets` option could be set.

    It is only available when `:igniter` is a dependency of the project, so
    guard code that uses it the same way that installer tasks are guarded:

    ```elixir
    if Code.ensure_loaded?(Igniter) do
      defmodule Mix.Tasks.NervesSystemMyBoard.Install do
        use Igniter.Mix.Task

        @impl Igniter.Mix.Task
        def igniter(igniter) do
          Nerves.Igniter.add_system(igniter, :nerves_system_my_board, :my_board,
            requirement: "~> 1.0"
          )
        end
      end
    end
    ```

    ## Targets and systems

    A Nerves *target* is the short name that users set `MIX_TARGET` to, like
    `:rpi4`. A Nerves *system* is the package that provides the Linux kernel,
    root filesystem and Erlang runtime for a target, like
    `:nerves_system_rpi4`. Projects link the two in their `mix.exs`
    dependencies:

    ```elixir
    {:nerves_system_rpi4, "~> 2.0", runtime: false, targets: :rpi4}
    ```

    `add_system/4` writes that line. `official_systems/0` is the table of
    targets that the Nerves core team maintains systems for.
    """

    alias Igniter.Project.Deps
    alias Sourceror.Zipper

    @typedoc "The short name of a device. I.e., what `MIX_TARGET` gets set to."
    @type target() :: atom()

    @typedoc "The OTP application name of a Nerves system. E.g., `:nerves_system_rpi4`"
    @type system_app() :: atom()

    # Keep in sync with nerves_bootstrap's `mix nerves.new`.
    @official_systems %{
      bbb: {:nerves_system_bbb, "~> 2.19"},
      grisp2: {:nerves_system_grisp2, "~> 0.8"},
      mangopi_mq_pro: {:nerves_system_mangopi_mq_pro, "~> 0.6"},
      npi_imx6ull: {:nerves_system_npi_imx6ull, "~> 0.21"},
      osd32mp1: {:nerves_system_osd32mp1, "~> 0.15"},
      qemu_aarch64: {:nerves_system_qemu_aarch64, "~> 0.1"},
      rpi: {:nerves_system_rpi, "~> 2.0"},
      rpi0: {:nerves_system_rpi0, "~> 2.0"},
      rpi0_2: {:nerves_system_rpi0_2, "~> 2.0"},
      rpi2: {:nerves_system_rpi2, "~> 2.0"},
      rpi3: {:nerves_system_rpi3, "~> 2.0"},
      rpi3a: {:nerves_system_rpi3a, "~> 2.0"},
      rpi4: {:nerves_system_rpi4, "~> 2.0"},
      rpi5: {:nerves_system_rpi5, "~> 2.0"},
      trellis: {:nerves_system_trellis, "~> 0.4"},
      x86_64: {:nerves_system_x86_64, "~> 1.24"}
    }

    @default_targets [
      :bbb,
      :mangopi_mq_pro,
      :qemu_aarch64,
      :rpi,
      :rpi0,
      :rpi0_2,
      :rpi2,
      :rpi3,
      :rpi4,
      :rpi5,
      :trellis,
      :x86_64
    ]

    @system_requirements Map.new(Map.values(@official_systems))

    # The `project/0` option that refers to a new `@all_targets` so that it
    # isn't an unused module attribute. Mix ignores options it doesn't know.
    @targets_key :nerves_targets

    @doc """
    Return the official Nerves targets and the systems that support them

    The result maps each target to its system package and the version
    requirement that new projects should use.

    ```elixir
    iex> Nerves.Igniter.official_systems()[:rpi4]
    {:nerves_system_rpi4, "~> 2.0"}
    ```
    """
    @spec official_systems() :: %{target() => {system_app(), requirement :: String.t()}}
    def official_systems(), do: @official_systems

    @doc """
    Return the targets that are added to a new project when none are specified

    This is the same list that `mix nerves.new` uses. All of them are keys in
    `official_systems/0`.
    """
    # The success typing is the list of literals, which trips :underspecs
    @dialyzer {:nowarn_function, default_targets: 0}
    @spec default_targets() :: [target()]
    def default_targets(), do: @default_targets

    @doc """
    Look up the official system for a target

    Returns `:error` for targets that aren't in `official_systems/0`.

    ```elixir
    iex> Nerves.Igniter.system_for_target(:rpi0)
    {:ok, {:nerves_system_rpi0, "~> 2.0"}}
    iex> Nerves.Igniter.system_for_target(:my_board)
    :error
    ```
    """
    @spec system_for_target(target()) :: {:ok, {system_app(), requirement :: String.t()}} | :error
    def system_for_target(target) when is_atom(target) do
      Map.fetch(@official_systems, target)
    end

    @doc """
    Add the official system for a target to the project

    This looks `target` up in `official_systems/0` and calls `add_system/4`.
    An Igniter issue is added for unknown targets, so that the installation
    stops with a helpful message rather than writing a `mix.exs` that can't
    work.
    """
    @spec add_target(Igniter.t(), target()) :: Igniter.t()
    def add_target(igniter, target) when is_atom(target) do
      case system_for_target(target) do
        {:ok, {system_app, requirement}} ->
          add_system(igniter, system_app, target, requirement: requirement)

        :error ->
          Igniter.add_issue(igniter, """
          Unknown Nerves target #{inspect(target)}

          The official targets are: #{Enum.map_join(official_targets(), ", ", &to_string/1)}

          If #{inspect(target)} is supported by a third-party or custom Nerves system,
          say where the system comes from. For example,

              mix nerves.add_target nerves_system_#{target}@github:me/nerves_system_#{target}

          See `mix help nerves.add_target`.
          """)
      end
    end

    @doc """
    Add a Nerves system to the project for the specified target

    This makes sure that the `mix.exs` dependencies have

    ```elixir
    {system_app, requirement, runtime: false, targets: target}
    ```

    and that `target` is in the project's `@all_targets` module attribute. See
    `ensure_all_targets/1` for what happens when `mix.exs` doesn't have that
    attribute yet.

    If `system_app` is already a dependency, its version requirement or source
    (`:path`, `:github`, ...) is kept. Only the options are updated: `runtime:
    false` is set and `target` is added to `:targets`. A `:targets` option that
    isn't a literal atom or list of atoms is left alone.

    Calling this more than once with the same arguments doesn't change
    anything.

    ## Options

    * `:requirement` - the version requirement to use when the dependency is
      added. Defaults to the one in `official_systems/0`. It or `:source` is
      required for systems that aren't in that table.
    * `:source` - where to get the system from when it isn't a Hex package.
      This is a keyword list with the dependency's source options like
      `[github: "me/nerves_system_my_board", ref: "main"]` or `[path:
      "../nerves_system_my_board"]`. The dependency is added without a version
      requirement unless `:requirement` is passed as well.
    """
    @spec add_system(Igniter.t(), system_app(), target(), keyword()) :: Igniter.t()
    def add_system(igniter, system_app, target, opts \\ [])
        when is_atom(system_app) and is_atom(target) and is_list(opts) do
      igniter =
        case existing_dep(igniter, system_app) do
          nil ->
            dep = new_system_dep(system_app, target, opts)

            igniter
            |> Deps.add_dep(dep, append?: true, on_exists: :skip)
            |> unbracket_dep_options(dep)

          dep_opts ->
            igniter
            |> ensure_runtime_false(system_app, dep_opts)
            |> ensure_dep_target(system_app, dep_opts, target)
        end

      if defines_all_targets?(igniter) do
        add_to_all_targets(igniter, target)
      else
        create_all_targets(igniter, Enum.uniq(project_targets(igniter) ++ [target]))
      end
    end

    @doc """
    Make sure that `mix.exs` has an `@all_targets` module attribute

    `@all_targets` lists the targets that the project builds firmware for.
    Dependencies that should be on every device, but not on the computer that
    the project is developed on, refer to it:

    ```elixir
    {:vintage_net, "~> 0.13", targets: @all_targets}
    ```

    Installers of libraries that must not run on the host look for the
    attribute to restrict their dependency like that, so `mix nerves.install`
    and `add_system/4` make sure that it exists.

    If `mix.exs` doesn't define `@all_targets`, it's added above `def project`,
    which is where `mix nerves.new` puts it, with the targets of the project's
    Nerves systems (see `project_targets/1`). Nothing is added when the
    project doesn't have any.

    Elixir warns about module attributes that are set, but never used, and
    nothing uses a new `@all_targets` until a library is restricted to it. To
    keep projects compiling without warnings, `#{@targets_key}: @all_targets`
    is added to the options that `project/0` returns when nothing else in
    `mix.exs` refers to the attribute. Mix ignores that option. It can be
    removed once a dependency has `targets: @all_targets`.

    An `@all_targets` that already exists is never changed here. `add_system/4`
    adds new targets to it.
    """
    @spec ensure_all_targets(Igniter.t()) :: Igniter.t()
    def ensure_all_targets(igniter) do
      if defines_all_targets?(igniter) do
        igniter
      else
        create_all_targets(igniter, project_targets(igniter))
      end
    end

    @doc """
    Return whether the project looks like a Nerves project

    A project is a Nerves project if it has a `config/target.exs` or if
    `:nerves` is one of its dependencies.
    """
    @spec nerves_project?(Igniter.t()) :: boolean()
    def nerves_project?(igniter) do
      Igniter.exists?(igniter, "config/target.exs") or Deps.has_dep?(igniter, :nerves)
    end

    @doc """
    Return the config file for configuration that's only for devices

    This is `"target.exs"` when the project has a `config/target.exs` and
    `"config.exs"` otherwise. The file name is relative to the `config`
    directory, which is what the `Igniter.Project.Config` functions expect.

    Installers that fall back to `"config.exs"` should add a notice, since
    the configuration will then also be used when running on the host.
    """
    @spec device_config_file(Igniter.t()) :: String.t()
    def device_config_file(igniter) do
      if Igniter.exists?(igniter, "config/target.exs"), do: "target.exs", else: "config.exs"
    end

    @doc """
    Return the config file for configuration that's only for the host

    This is `"host.exs"` when the project has a `config/host.exs`. Otherwise,
    it's `nil` and host-only configuration, like mocks for hardware, shouldn't
    be written, since it would end up on devices.
    """
    @spec host_config_file(Igniter.t()) :: String.t() | nil
    def host_config_file(igniter) do
      if Igniter.exists?(igniter, "config/host.exs"), do: "host.exs", else: nil
    end

    @doc """
    Return the targets that the project has Nerves systems for

    The targets are found by looking through `mix.exs` for `nerves_system_*`
    dependencies that have literal `:targets` options. They're returned in
    the order that they're listed.
    """
    @spec project_targets(Igniter.t()) :: [target()]
    def project_targets(igniter) do
      case Code.string_to_quoted(mix_exs_content(igniter)) do
        {:ok, quoted} ->
          {_quoted, targets} = Macro.prewalk(quoted, [], &collect_system_targets/2)
          targets |> Enum.reverse() |> Enum.uniq()

        {:error, _} ->
          []
      end
    end

    defp official_targets(), do: @official_systems |> Map.keys() |> Enum.sort()

    defp new_system_dep(system_app, target, opts) do
      source = Keyword.get(opts, :source, [])

      if not Keyword.keyword?(source) do
        raise ArgumentError, "expected :source to be a keyword list, got: #{inspect(source)}"
      end

      dep_opts = source ++ [runtime: false, targets: target]

      if source == [] or Keyword.has_key?(opts, :requirement) do
        {system_app, fetch_requirement!(system_app, opts), dep_opts}
      else
        {system_app, dep_opts}
      end
    end

    # Igniter writes a dependency without a version requirement as
    # `{:app, [path: "..."]}`. Rewrite it the way that it's normally written.
    defp unbracket_dep_options(igniter, {app, dep_opts}) do
      code = "{#{inspect(app)}, #{dep_opts |> inspect() |> String.slice(1..-2//1)}}"

      Igniter.update_elixir_file(igniter, "mix.exs", fn zipper ->
        case Zipper.find(zipper, &bracketed_dep?(&1, app)) do
          nil -> {:ok, zipper}
          dep -> {:ok, Igniter.Code.Common.replace_code(dep, code)}
        end
      end)
    end

    defp unbracket_dep_options(igniter, _dep), do: igniter

    defp bracketed_dep?({:__block__, _, [{name, options}]}, app) do
      unwrap(name) == app and is_list(unwrap(options))
    end

    defp bracketed_dep?(_node, _app), do: false

    # Sourceror wraps literals in `:__block__` nodes to hold their metadata
    defp unwrap({:__block__, _, [value]}), do: value
    defp unwrap(value), do: value

    defp fetch_requirement!(system_app, opts) do
      case Keyword.fetch(opts, :requirement) do
        {:ok, requirement} when is_binary(requirement) ->
          requirement

        {:ok, other} ->
          raise ArgumentError,
                "expected :requirement to be a version requirement string, got: #{inspect(other)}"

        :error ->
          Map.get(@system_requirements, system_app) ||
            raise ArgumentError,
                  "#{inspect(system_app)} isn't an official Nerves system, so the :requirement option is required"
      end
    end

    defp mix_exs_content(igniter) do
      igniter
      |> Igniter.include_existing_file("mix.exs")
      |> Map.fetch!(:rewrite)
      |> Rewrite.source!("mix.exs")
      |> Rewrite.Source.get(:content)
    end

    defp collect_system_targets({:{}, _, [app, _requirement, opts]} = node, acc),
      do: {node, collect_system_targets(app, opts, acc)}

    defp collect_system_targets({app, opts} = node, acc) when is_atom(app) and is_list(opts),
      do: {node, collect_system_targets(app, opts, acc)}

    defp collect_system_targets(node, acc), do: {node, acc}

    defp collect_system_targets(app, opts, acc) do
      if is_atom(app) and system_app?(app) and Keyword.keyword?(opts) do
        case Keyword.get(opts, :targets) do
          target when is_atom(target) and not is_nil(target) ->
            [target | acc]

          targets when is_list(targets) ->
            if Enum.all?(targets, &is_atom/1), do: Enum.reverse(targets) ++ acc, else: acc

          _ ->
            acc
        end
      else
        acc
      end
    end

    defp system_app?(app), do: String.starts_with?(Atom.to_string(app), "nerves_system_")

    # Returns the dependency's options as quoted code or nil if there's no
    # such dependency.
    defp existing_dep(igniter, app) do
      with {:ok, declaration} when is_binary(declaration) <- Deps.get_dep(igniter, app),
           {:ok, quoted} <- Code.string_to_quoted(declaration) do
        case quoted do
          {:{}, _, [^app, _requirement, opts]} when is_list(opts) -> opts
          {^app, opts} when is_list(opts) -> opts
          _ -> []
        end
      else
        _ -> nil
      end
    end

    defp ensure_runtime_false(igniter, app, dep_opts) do
      if Keyword.keyword?(dep_opts) and Keyword.get(dep_opts, :runtime) == false do
        igniter
      else
        Deps.set_dep_option(igniter, app, :runtime, false)
      end
    end

    defp ensure_dep_target(igniter, app, dep_opts, target) do
      current = if Keyword.keyword?(dep_opts), do: Keyword.fetch(dep_opts, :targets), else: :error

      case current do
        :error ->
          Deps.set_dep_option(igniter, app, :targets, target)

        {:ok, ^target} ->
          igniter

        {:ok, other} when is_atom(other) ->
          Deps.set_dep_option(igniter, app, :targets, [other, target])

        {:ok, targets} when is_list(targets) ->
          if target in targets or not Enum.all?(targets, &is_atom/1) do
            igniter
          else
            Deps.set_dep_option(igniter, app, :targets, targets ++ [target])
          end

        {:ok, _computed} ->
          # E.g., `targets: @all_targets`. That attribute is handled separately.
          igniter
      end
    end

    defp add_to_all_targets(igniter, target) do
      Igniter.update_elixir_file(igniter, "mix.exs", fn zipper ->
        with %Zipper{} = attribute <- Zipper.find(zipper, &all_targets_attribute?/1),
             list when not is_nil(list) <- attribute |> Zipper.down() |> Zipper.down(),
             true <- Igniter.Code.List.list?(list),
             {:ok, list} <- Igniter.Code.List.append_new_to_list(list, target) do
          {:ok, list}
        else
          _ -> {:ok, zipper}
        end
      end)
    end

    defp create_all_targets(igniter, []), do: igniter

    # `mix nerves.new` puts the attribute below `@version`, right above
    # `def project`. It's added as text to get the same blank lines.
    defp create_all_targets(igniter, targets) do
      igniter =
        Igniter.update_file(igniter, "mix.exs", fn source ->
          lines = source |> Rewrite.Source.get(:content) |> String.split("\n")

          case Enum.find_index(lines, &(&1 =~ ~r/^\s*def project\b/)) do
            nil ->
              source

            index ->
              {above, rest} = Enum.split(lines, index)
              [indent] = Regex.run(~r/^\s*/, hd(rest))
              above = above |> Enum.reverse() |> Enum.drop_while(&(String.trim(&1) == ""))
              # Other module attributes are kept together with this one
              separator = if above != [] and hd(above) =~ ~r/^\s*@\w+ /, do: [], else: [""]
              attribute = "#{indent}@all_targets #{inspect(targets)}"
              lines = Enum.reverse(above) ++ separator ++ [attribute, ""] ++ rest

              Rewrite.Source.update(source, :content, Enum.join(lines, "\n"))
          end
        end)

      cond do
        not defines_all_targets?(igniter) ->
          Igniter.add_warning(igniter, """
          nerves: could not add `@all_targets #{inspect(targets)}` to mix.exs. Libraries
          that shouldn't run on your computer use that module attribute to
          restrict their dependency to devices (`targets: @all_targets`).
          """)

        uses_all_targets?(igniter) ->
          igniter

        true ->
          # Without this, every Mix command warns that the attribute is unused
          # until a dependency refers to it.
          Igniter.Project.MixProject.update(igniter, :project, [@targets_key], fn
            nil -> {:ok, {:code, {:@, [], [{:all_targets, [], nil}]}}}
            zipper -> {:ok, zipper}
          end)
      end
    end

    defp defines_all_targets?(igniter), do: any_mix_exs_node?(igniter, &all_targets_attribute?/1)
    defp uses_all_targets?(igniter), do: any_mix_exs_node?(igniter, &all_targets_use?/1)

    defp any_mix_exs_node?(igniter, fun) do
      case Code.string_to_quoted(mix_exs_content(igniter)) do
        {:ok, quoted} ->
          {_quoted, found?} = Macro.prewalk(quoted, false, &{&1, &2 or fun.(&1)})
          found?

        {:error, _} ->
          false
      end
    end

    defp all_targets_use?({:@, _, [{:all_targets, _, context}]}) when is_atom(context), do: true
    defp all_targets_use?(_node), do: false

    defp all_targets_attribute?({:@, _, [{:all_targets, _, [_value]}]}), do: true
    defp all_targets_attribute?(_node), do: false
  end
end
