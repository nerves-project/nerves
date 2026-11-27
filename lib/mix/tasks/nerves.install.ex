# SPDX-FileCopyrightText: 2026 Lars Wikman
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.Install.Docs do
  @moduledoc false

  # The libraries that give `mix nerves.new` projects SSH, mDNS, networking
  # and time synchronization. They're not installed by `mix nerves.install`.
  # This is the order to pass them to `mix igniter.install` to get a
  # `config/target.exs` like the one in nerves_bootstrap's project template.
  # nerves_bootstrap's `mix nerves.new --igniter` has the same list.
  @networking_packages [
    "nerves_ssh",
    "mdns_lite",
    "vintage_net",
    "vintage_net_direct",
    "vintage_net_ethernet",
    "vintage_net_wifi",
    "nerves_time",
    "nerves_motd"
  ]

  @spec short_doc() :: String.t()
  def short_doc() do
    "Turns a Mix project into a Nerves project"
  end

  @spec example() :: String.t()
  def example() do
    "mix igniter.install nerves --target rpi4"
  end

  @spec long_doc() :: String.t()
  def long_doc() do
    """
    #{short_doc()}

    This sets up everything that the Nerves tooling needs to build firmware
    from a project that was created with `mix new` or `mix igniter.new`.

    ## Examples

    Create a new Nerves project for the Raspberry Pi 4 and Raspberry Pi Zero:

    ```bash
    mix igniter.new my_app --install nerves --target rpi4 --target rpi0
    ```

    Create a new Nerves project with SSH, mDNS, networking and time
    synchronization like `mix nerves.new` does:

    ```bash
    mix igniter.new my_app --install nerves,#{Enum.join(@networking_packages, ",")} --target rpi4
    ```

    List `nerves` first so that the other installers find a Nerves project,
    and leave out the libraries that you don't need.

    Add Nerves to an existing project:

    ```bash
    #{example()}
    ```

    ## What it does

    * Updates `mix.exs`:
        * Marks the `:nerves` dependency as `runtime: false`
        * Marks the `:igniter` dependency as `runtime: false`, if there is
          one, so that Igniter doesn't end up in the firmware
        * Requires the `nerves_bootstrap` archive via `:archives`
        * Adds the `:releases` configuration and a `release/0` function that
          hooks Nerves into `mix release`
        * Adds `cli/0` with `:preferred_targets` so that `mix run` and `mix
          test` always run on the host
        * Adds `:runtime_tools` to `:extra_applications` (new Nerves projects
          only)
        * Adds the Nerves system for each target
        * Adds the `@all_targets` module attribute with the project's targets
          if it's missing. Libraries that shouldn't run on your computer
          restrict their dependency to it (`targets: @all_targets`). Until
          one does, `project/0` refers to the attribute so that Elixir doesn't
          warn that it's unused.
        * Adds `shoehorn`, `nerves_runtime`, `ring_logger` and `toolshed`
    * Creates or updates `config/config.exs` to start the Nerves integration
      with Mix, set the `rootfs_overlay` directory and `SOURCE_DATE_EPOCH`, and
      import `config/host.exs` or `config/target.exs` depending on the Mix
      target
    * Creates `config/host.exs` for configuration that's only for running on
      your computer and `config/target.exs` for configuration that's only for
      devices
    * Configures the device's clock to be advanced at boot (`config :nerves,
      :erlinit, update_clock: true` in `config/target.exs`) unless erlinit is
      already configured
    * Creates `rel/vm.args.eex` with the Erlang VM flags that are used on
      devices
    * Creates `rootfs_overlay/etc/iex.exs`, the device's IEx startup file
    * Adds `rootfs_overlay/etc/iex.exs` to the `.formatter.exs` inputs and
      firmware images to `.gitignore`
    * In projects that aren't Nerves projects yet: creates the application
      module with separate lists of children for the host and for devices
      when there's none (or when it's the unmodified one from `mix new
      --sup`), and replaces the `README.md` from `mix new` if it's unmodified
    * Runs the `shoehorn`, `nerves_runtime`, `ring_logger` and `toolshed`
      installers when the versions that were fetched have them

    Files that exist and settings that are already present are kept, so it's
    safe to run this in an existing Nerves project.

    Networking isn't set up. Add the libraries that you want to the list of
    packages to install for that. `mix nerves.new` projects have
    #{Enum.map_join(@networking_packages, ", ", &"`#{&1}`")}.

    ## Options

    * `--target` - A target to add the official Nerves system for. Pass it more
      than once or separate targets with commas to add more than one: `--target
      rpi4 --target rpi0` or `--target rpi4,rpi0`. If unspecified and the
      project doesn't have any Nerves systems yet, the same systems that `mix
      nerves.new` uses are added: #{default_targets()}. If the project already
      has a Nerves system, none are added.

    To add a target to a project later, run `mix nerves.add_target <target>`.

    The official targets are: #{official_targets()}
    """
  end

  if Code.ensure_loaded?(Igniter) do
    defp default_targets(), do: Enum.map_join(Nerves.Igniter.default_targets(), ", ", &"`#{&1}`")

    defp official_targets() do
      Nerves.Igniter.official_systems()
      |> Map.keys()
      |> Enum.sort()
      |> Enum.map_join(", ", &"`#{&1}`")
    end
  else
    defp default_targets(), do: "(install `igniter` to see the list)"
    defp official_targets(), do: "(install `igniter` to see the list)"
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Nerves.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    alias Igniter.Code.Common
    alias Igniter.Code.Function
    alias Igniter.Project.Config
    alias Igniter.Project.Deps
    alias Igniter.Project.MixProject
    alias Sourceror.Zipper

    # Prereleases are only matched by requirements that have a prerelease part
    @nerves_requirement (case Version.parse!(Mix.Project.config()[:version]) do
                           %Version{pre: []} = v -> "~> #{v.major}.#{v.minor}"
                           v -> "~> #{v}"
                         end)

    # The nerves_bootstrap archive supplies the Mix aliases that let Nerves
    # set up cross-compilation before anything is compiled.
    @bootstrap_requirement "~> 1.17"

    # Packages that every Nerves project has. See nerves_bootstrap's project
    # template. Their installers are run when they exist.
    @companions [
      {:shoehorn, "~> 0.9.1"},
      {:nerves_runtime, "~> 0.13.12"},
      {:ring_logger, "~> 0.11.0"},
      {:toolshed, "~> 0.5.0"}
    ]

    @config_exs """
    # This file is responsible for configuring your application and its
    # dependencies.
    #
    # This configuration file is loaded before any dependency and is restricted to
    # this project.
    import Config

    # Enable the Nerves integration with Mix
    Application.start(:nerves_bootstrap)

    # Customize non-Elixir parts of the firmware. See
    # https://nerves.hexdocs.pm/advanced-configuration.html for details.

    config :nerves, :firmware, rootfs_overlay: "rootfs_overlay"

    # Set the SOURCE_DATE_EPOCH date for reproducible builds.
    # See https://reproducible-builds.org/docs/source-date-epoch/ for more information

    config :nerves, source_date_epoch: "{{epoch}}"

    if Mix.target() == :host do
      import_config "host.exs"
    else
      import_config "target.exs"
    end
    """

    @import_target_config """
    if Mix.target() == :host do
      import_config "host.exs"
    else
      import_config "target.exs"
    end
    """

    @host_exs """
    import Config

    # Add configuration that is only needed when running on the host here.
    """

    @target_exs """
    import Config

    # Use shoehorn to start the main application. See the shoehorn
    # library documentation for more control in ordering how OTP
    # applications are started and handling failures.

    config :shoehorn, init: [:nerves_runtime]

    # Import target specific config. This must remain at the bottom
    # of this file so it overrides the configuration defined above.
    # Uncomment to use target specific configurations

    # import_config "\#{Mix.target()}.exs"
    """

    @update_clock """
    # Erlinit can be configured without a rootfs_overlay. See
    # https://github.com/nerves-project/erlinit/ for more information on
    # configuring erlinit.

    # Advance the system clock on devices without a real-time clock.
    config :nerves, :erlinit, update_clock: true
    """

    @vm_args ~S"""
    ## Customize flags given to the VM: https://www.erlang.org/doc/apps/erts/erl_cmd.html

    ## Do not set -name or -sname here. Prefer configuring them at runtime
    ## Configure -setcookie in the mix.exs release section or at runtime

    ## Number of dirty schedulers doing IO work (file, sockets, and others)
    ##+SDio 5

    ## Increase number of concurrent ports/sockets
    ##+Q 65536

    ## Tweak GC to run more often
    ##-env ERL_FULLSWEEP_AFTER 10

    ## Use Ctrl-C to interrupt the current shell rather than invoking the emulator's
    ## break handler and possibly exiting the VM.
    +Bc

    ## Require an initialization handshake within 10 minutes from the startup guard
    ## See https://nerves-runtime.hexdocs.pm/readme.html#assisted-firmware-validation-and-automatic-revert
    -env HEART_INIT_TIMEOUT 600

    # Allow time warps so that the Erlang system time can more closely match the
    # OS system time.
    +C multi_time_warp

    ## Choose whether to load all code at system startup
    ## See https://www.erlang.org/doc/system/system_principles.html#code-loading-strategy
    ## Slow devices sometimes benefit from choosing embedded mode
    ##-mode interactive

    # Load code as per the boot script since not using archives
    # See https://www.erlang.org/doc/man/init.html#command-line-flags
    -code_path_choice strict

    ## Disable scheduler busy wait to reduce idle CPU usage and avoid delaying
    ## other OS processes. See https://www.erlang.org/doc/apps/erts/erl_cmd.html#+sbwt
    +sbwt none
    +sbwtdcpu none
    +sbwtdio none

    ## Save the shell history between reboots
    ## See https://www.erlang.org/doc/apps/kernel/kernel_app for additional options
    -kernel shell_history enabled

    ## Enable heartbeat monitoring of the Erlang runtime system
    -heart -env HEART_BEAT_TIMEOUT 30

    ## Start the Elixir shell

    -noshell
    -user elixir
    -run elixir start_cli

    ## Enable colors in the shell
    -elixir ansi_enabled true

    ## Options added after -extra are interpreted as plain arguments and can be
    ## retrieved using :init.get_plain_arguments(). Options before the "--" are
    ## interpreted by Elixir and anything afterwards is left around for other IEx
    ## and user applications.
    -extra --no-halt
    --
    --dot-iex /etc/iex.exs
    """

    @iex_exs """
    # This file is run when an IEx session starts on the device. Use it to
    # import helpers or print information that's handy to have at the prompt.
    """

    @iex_exs_path "rootfs_overlay/etc/iex.exs"

    @application_module """
    defmodule {{module}} do
      # See https://elixir.hexdocs.pm/Application.html
      # for more information on OTP Applications
      @moduledoc false

      use Application

      @impl true
      def start(_type, _args) do
        children =
          [
            # Children for all targets
            # Starts a worker by calling: {{worker}}.start_link(arg)
            # {{{worker}}, arg},
          ] ++ target_children()

        # See https://elixir.hexdocs.pm/Supervisor.html
        # for other strategies and supported options
        opts = [strategy: :one_for_one, name: {{supervisor}}]
        Supervisor.start_link(children, opts)
      end

      # List all child processes to be supervised
      if Mix.target() == :host do
        defp target_children() do
          [
            # Children that only run on the host during development or test.
            # In general, prefer using `config/host.exs` for differences.
            #
            # Starts a worker by calling: Host.Worker.start_link(arg)
            # {Host.Worker, arg},
          ]
        end
      else
        defp target_children() do
          [
            # Children for all targets except host
            # Starts a worker by calling: Target.Worker.start_link(arg)
            # {Target.Worker, arg},
          ]
        end
      end
    end
    """

    # What `mix new --sup` generates
    @stock_application_module """
    defmodule {{module}} do
      # See https://hexdocs.pm/elixir/Application.html
      # for more information on OTP Applications
      @moduledoc false

      use Application

      @impl true
      def start(_type, _args) do
        children = [
          # Starts a worker by calling: {{worker}}.start_link(arg)
          # {{{worker}}, arg}
        ]

        # See https://hexdocs.pm/elixir/Supervisor.html
        # for other strategies and supported options
        opts = [strategy: :one_for_one, name: {{supervisor}}]
        Supervisor.start_link(children, opts)
      end
    end
    """

    # What `mix new` generates below the title
    @stock_readme_body """

    **TODO: Add description**

    ## Installation

    If [available in Hex](https://hex.pm/docs/publish), the package can be installed
    by adding `{{app}}` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [
        {:{{app}}, "~> 0.1.0"}
      ]
    end
    ```

    Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
    and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
    be found at <https://hexdocs.pm/{{app}}>.
    """

    @readme_body """

    **TODO: Add description**

    ## Targets

    Nerves applications produce images for hardware targets based on the
    `MIX_TARGET` environment variable. If `MIX_TARGET` is unset, `mix` builds an
    image that runs on the host (e.g., your laptop). This is useful for executing
    logic tests, running utilities, and debugging. Other targets are represented by
    a short name like `rpi5` that maps to a Nerves system image for that platform.
    All of this logic is in the generated `mix.exs` and may be customized. For more
    information about targets see:

    https://nerves.hexdocs.pm/supported-targets.html

    ## Getting Started

    To start your Nerves app:
      * `export MIX_TARGET=my_target` or prefix every command with
        `MIX_TARGET=my_target`. For example, `MIX_TARGET=rpi5`
      * Install dependencies with `mix deps.get`
      * Create firmware with `mix firmware`
      * Burn to an SD card with `mix burn`

    ## Learn more

      * Official docs: https://nerves.hexdocs.pm/getting-started.html
      * Official website: https://nerves-project.org/
      * Forum: https://elixirforum.com/c/nerves-forum
      * Elixir Discord #nerves channel: https://discord.gg/elixir
      * Source: https://github.com/nerves-project/nerves
    """

    @gitignore """
    # Firmware images created by "mix firmware.image"
    /*.img
    """

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :nerves,
        example: __MODULE__.Docs.example(),
        schema: [target: :keep],
        # The companions are added here so that `mix igniter.install` fetches
        # them before this task runs. They're deliberately not listed under
        # `installs`: Igniter runs the installers of `installs` before the
        # task that asked for them, but these need the files that this task
        # creates. See `install_companions/1`.
        adds_deps: new_companions(),
        composes: Enum.map(@companions, fn {app, _requirement} -> "#{app}.install" end)
      }
    end

    # Igniter replaces dependencies that are in the mix.exs with the ones from
    # `adds_deps` when their declarations differ. Projects that already use a
    # companion keep their version of it.
    defp new_companions() do
      existing =
        for dep <- List.wrap(Mix.Project.config()[:deps]), is_tuple(dep), do: elem(dep, 0)

      Enum.reject(@companions, fn {app, _requirement} -> app in existing end)
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      case parse_targets(igniter.args.options[:target]) do
        {:ok, targets} ->
          # `mix igniter.install` adds the nerves dependency before this runs,
          # so only the config file tells whether Nerves was already set up.
          already_nerves? = Igniter.exists?(igniter, "config/target.exs")

          igniter
          |> update_nerves_dep()
          |> keep_igniter_out_of_firmware()
          |> add_archives()
          |> add_new_project_extras(already_nerves?)
          |> add_release()
          |> add_preferred_targets()
          |> update_config_exs()
          |> Igniter.create_or_update_file("config/host.exs", @host_exs, & &1)
          |> update_target_exs()
          |> advance_clock_at_boot()
          |> Igniter.create_or_update_file("rel/vm.args.eex", @vm_args, & &1)
          |> Igniter.create_or_update_file(@iex_exs_path, @iex_exs, & &1)
          |> update_formatter()
          |> update_gitignore()
          |> install_companions()
          |> add_systems(targets)
          |> Nerves.Igniter.ensure_all_targets()
          |> add_next_steps_notice(already_nerves?)

        {:error, unknown} ->
          Enum.reduce(unknown, igniter, &Nerves.Igniter.add_target(&2, &1))
      end
    end

    # -- Options ---------------------------------------------------------------

    # Returns the targets that were passed. All of them are known to be
    # official targets, so creating atoms for them is fine.
    defp parse_targets(values) do
      official = Map.new(Nerves.Igniter.official_systems(), fn {k, _} -> {to_string(k), k} end)

      names =
        values
        |> List.wrap()
        |> Enum.flat_map(&String.split(&1, ",", trim: true))
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.uniq()

      case Enum.reject(names, &Map.has_key?(official, &1)) do
        [] -> {:ok, Enum.map(names, &Map.fetch!(official, &1))}
        # The unknown targets end up in an error message and nowhere else
        unknown -> {:error, Enum.map(unknown, &String.to_atom/1)}
      end
    end

    # -- mix.exs ---------------------------------------------------------------

    defp update_nerves_dep(igniter) do
      if Deps.has_dep?(igniter, :nerves) do
        if dep_option(igniter, :nerves, :runtime) == {:ok, false} do
          igniter
        else
          Deps.set_dep_option(igniter, :nerves, :runtime, false)
        end
      else
        Deps.add_dep(igniter, {:nerves, nerves_requirement(), runtime: false},
          append?: true,
          on_exists: :skip
        )
      end
    end

    defp nerves_requirement(), do: @nerves_requirement

    # `mix igniter.new` and `mix igniter.install` add Igniter to the project
    # as `{:igniter, "~> 0.6", only: [:dev, :test]}`. That makes it an
    # application that the project needs at runtime, so Igniter and all of
    # its dependencies end up in firmware that's built with `MIX_ENV=dev`.
    # It's only used by Mix tasks. An explicit `:runtime` option is kept.
    defp keep_igniter_out_of_firmware(igniter) do
      if Deps.has_dep?(igniter, :igniter) and dep_option(igniter, :igniter, :runtime) == :error do
        Deps.set_dep_option(igniter, :igniter, :runtime, false)
      else
        igniter
      end
    end

    defp dep_option(igniter, app, key) do
      with {:ok, declaration} when is_binary(declaration) <- Deps.get_dep(igniter, app),
           {:ok, {:{}, _, [^app, _requirement, opts]}} <- Code.string_to_quoted(declaration),
           true <- Keyword.keyword?(opts) do
        Keyword.fetch(opts, key)
      else
        _ -> :error
      end
    end

    defp add_archives(igniter) do
      MixProject.update(igniter, :project, [:archives], fn
        nil -> {:ok, {:code, [nerves_bootstrap: @bootstrap_requirement]}}
        zipper -> {:ok, zipper}
      end)
    end

    # -- Things that only new Nerves projects get -------------------------------

    # These bring a `mix new` project in line with what `mix nerves.new`
    # generates. They're skipped for projects that are already Nerves projects
    # since their absence there is most likely deliberate.
    defp add_new_project_extras(igniter, true = _already_nerves?), do: igniter

    defp add_new_project_extras(igniter, false) do
      igniter
      |> add_runtime_tools()
      |> add_application_module()
      |> replace_stock_readme()
    end

    # `:runtime_tools` has the `:observer` backend, `:dbg` and other tools that
    # are handy when debugging a device.
    defp add_runtime_tools(igniter) do
      MixProject.update(igniter, :application, [:extra_applications], fn
        nil ->
          {:ok, {:code, [:logger, :runtime_tools]}}

        zipper ->
          if Igniter.Code.List.list?(zipper) do
            Igniter.Code.List.append_new_to_list(zipper, :runtime_tools)
          else
            {:ok, zipper}
          end
      end)
    end

    # The application module of `mix nerves.new` projects has separate lists
    # of children for the host and for devices. It's created when the project
    # doesn't have an application module and replaces the one from `mix new
    # --sup` when that hasn't been modified. Anything else is left alone.
    defp add_application_module(igniter) do
      module = Igniter.Project.Module.module_name(igniter, "Application")
      path = Igniter.Project.Module.proper_location(igniter, module)
      contents = application_module(igniter, module)

      case Igniter.Project.Application.app_module(igniter) do
        nil ->
          if Igniter.exists?(igniter, path) do
            igniter
          else
            igniter
            |> MixProject.update(:application, [:mod], fn
              nil -> {:ok, {:code, Sourceror.parse_string!("{#{inspect(module)}, []}")}}
              zipper -> {:ok, zipper}
            end)
            |> Igniter.create_new_file(path, contents)
          end

        ^module ->
          if Igniter.exists?(igniter, path) and
               same_text?(read(igniter, path), stock_application_module(igniter, module)) do
            Igniter.update_file(igniter, path, &Rewrite.Source.update(&1, :content, contents))
          else
            igniter
          end

        _other ->
          igniter
      end
    end

    defp application_module(igniter, module) do
      supervisor = Igniter.Project.Module.module_name(igniter, "Supervisor")
      worker = Igniter.Project.Module.module_name(igniter, "Worker")

      @application_module
      |> String.replace("{{module}}", inspect(module))
      |> String.replace("{{supervisor}}", inspect(supervisor))
      |> String.replace("{{worker}}", inspect(worker))
    end

    defp stock_application_module(igniter, module) do
      supervisor = Igniter.Project.Module.module_name(igniter, "Supervisor")
      worker = Igniter.Project.Module.module_name(igniter, "Worker")

      @stock_application_module
      |> String.replace("{{module}}", inspect(module))
      |> String.replace("{{supervisor}}", inspect(supervisor))
      |> String.replace("{{worker}}", inspect(worker))
    end

    # The README that `mix new` generates describes how to use the project as
    # a Hex package. It's replaced with the one from `mix nerves.new` unless
    # it was edited.
    defp replace_stock_readme(igniter) do
      path = "README.md"
      app = Igniter.Project.Application.app_name(igniter)

      with true <- Igniter.exists?(igniter, path),
           content = read(igniter, path),
           [title, rest] <- String.split(content, "\n", parts: 2),
           true <- title =~ ~r/^# \S+$/,
           true <- same_text?(rest, String.replace(@stock_readme_body, "{{app}}", "#{app}")) do
        Igniter.update_file(
          igniter,
          path,
          &Rewrite.Source.update(&1, :content, title <> "\n" <> @readme_body)
        )
      else
        _ -> igniter
      end
    end

    # Compares ignoring indentation and blank lines so that reformatted, but
    # otherwise untouched files still match.
    defp same_text?(a, b), do: significant_lines(a) == significant_lines(b)

    defp significant_lines(text) do
      text
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
    end

    defp add_release(igniter) do
      app = Igniter.Project.Application.app_name(igniter)
      mix_exs = read(igniter, "mix.exs")

      cond do
        mix_exs =~ "Nerves.Release.init" ->
          igniter

        configures_releases?(igniter) ->
          Igniter.add_notice(igniter, """
          nerves: mix.exs already has a :releases configuration, so it was left as is.
          Nerves needs to be hooked into the release that's used for the firmware.
          Make sure that its options include:

              include_erts: &Nerves.Release.erts/0,
              steps: [&Nerves.Release.init/1, :assemble]
          """)

        true ->
          igniter
          |> MixProject.update(:project, [:releases], fn _ ->
            {:ok, {:code, Sourceror.parse_string!("[{#{inspect(app)}, release()}]")}}
          end)
          |> add_release_function(app)
      end
    end

    defp configures_releases?(igniter) do
      zipper = igniter |> read(:quoted, "mix.exs") |> Zipper.zip()

      with {:ok, zipper} <- Function.move_to_def(zipper, :project, 0),
           zipper = Common.rightmost(zipper),
           true <- Igniter.Code.List.list?(zipper),
           {:ok, _zipper} <- Igniter.Code.Keyword.get_key(zipper, :releases) do
        true
      else
        _ -> false
      end
    end

    defp add_release_function(igniter, app) do
      Igniter.update_elixir_file(igniter, "mix.exs", fn zipper ->
        if defines?(zipper, :release) do
          {:ok, zipper}
        else
          case last_def(zipper) do
            nil -> {:warning, "nerves: could not add the release/0 function to mix.exs"}
            last -> {:ok, Common.add_code(last, release_function(app))}
          end
        end
      end)
    end

    defp release_function(app) do
      """
      def release do
        [
          overwrite: true,
          cookie: "#{app}_cookie",
          include_erts: &Nerves.Release.erts/0,
          steps: [&Nerves.Release.init/1, :assemble],
          strip_beams: Mix.env() == :prod or [keep: ["Docs"]]
        ]
      end
      """
    end

    defp defines?(zipper, name) do
      match?({:ok, _}, Function.move_to_def(zipper, name, 0)) or
        match?({:ok, _}, Function.move_to_defp(zipper, name, 0))
    end

    defp last_def(zipper, last \\ nil) do
      with {:ok, zipper} <- Function.move_to_def(zipper),
           {:ok, next} <- Common.move_right(zipper, 1) do
        last_def(next, zipper)
      else
        _ -> last
      end
    end

    # `mix run` and `mix test` can't run code that was compiled for a device,
    # so they always use the host target.
    defp add_preferred_targets(igniter) do
      Enum.reduce([:run, :test], igniter, fn task, igniter ->
        MixProject.update(igniter, :cli, [:preferred_targets, task], fn
          nil -> {:ok, {:code, :host}}
          zipper -> {:ok, zipper}
        end)
      end)
    end

    defp add_systems(igniter, []) do
      if Nerves.Igniter.project_targets(igniter) == [] and not any_system_dep?(igniter) do
        add_systems(igniter, Nerves.Igniter.default_targets())
      else
        igniter
      end
    end

    defp add_systems(igniter, targets) do
      Enum.reduce(targets, igniter, &Nerves.Igniter.add_target(&2, &1))
    end

    # Catches systems with `:targets` options that `project_targets/1` can't
    # read, like module attributes, and custom systems.
    defp any_system_dep?(igniter) do
      read(igniter, "mix.exs") =~ ~r/\{\s*:nerves_system_/
    end

    # -- config ----------------------------------------------------------------

    defp update_config_exs(igniter) do
      path = "config/config.exs"
      source_date_epoch = Integer.to_string(System.os_time(:second))

      if Igniter.exists?(igniter, path) do
        igniter
        |> Igniter.update_elixir_file(path, &add_bootstrap_start/1)
        |> Igniter.update_elixir_file(path, &add_import_target_config/1)
        |> Config.configure_new(
          "config.exs",
          :nerves,
          [:firmware, :rootfs_overlay],
          "rootfs_overlay"
        )
        |> Config.configure_new("config.exs", :nerves, [:source_date_epoch], source_date_epoch)
      else
        contents = String.replace(@config_exs, "{{epoch}}", source_date_epoch)
        Igniter.create_new_file(igniter, path, contents)
      end
    end

    defp add_bootstrap_start(zipper) do
      if any_node?(zipper, &bootstrap_start?/1) do
        {:ok, zipper}
      else
        code = """
        # Enable the Nerves integration with Mix
        Application.start(:nerves_bootstrap)
        """

        zipper = Common.maybe_move_to_block(zipper)

        case Function.move_to_function_call_in_current_scope(zipper, :import, 1) do
          {:ok, import} -> {:ok, Common.add_code(import, code, placement: :after)}
          :error -> {:ok, Common.add_code(zipper, code, placement: :before)}
        end
      end
    end

    defp bootstrap_start?({{:., _, [{:__aliases__, _, [:Application]}, start]}, _, [app | _]})
         when start in [:start, :ensure_all_started, :ensure_started],
         do: unwrap(app) == :nerves_bootstrap

    defp bootstrap_start?(_node), do: false

    defp add_import_target_config(zipper) do
      if any_node?(zipper, &import_config?(&1, "target.exs")) do
        {:ok, zipper}
      else
        {:ok, zipper |> Zipper.topmost() |> append_code(@import_target_config)}
      end
    end

    defp append_code(zipper, code) do
      case zipper.node do
        {:__block__, _, [_ | _]} ->
          zipper
          |> Zipper.down()
          |> Zipper.rightmost()
          |> Common.add_code(code, placement: :after)

        _ ->
          Common.add_code(zipper, code, placement: :after)
      end
    end

    defp import_config?({:import_config, _, [file]}, name), do: unwrap(file) == name
    defp import_config?(_node, _name), do: false

    defp update_target_exs(igniter) do
      path = "config/target.exs"

      cond do
        not Igniter.exists?(igniter, path) ->
          # nerves_runtime is always added, so it's always in the release.
          Igniter.create_new_file(igniter, path, @target_exs)

        configured_in(igniter, :shoehorn, [:init]) != nil ->
          igniter

        true ->
          Config.configure_new(igniter, "target.exs", :shoehorn, [:init], [:nerves_runtime])
      end
    end

    defp configured_in(igniter, app, path) do
      Enum.find(["target.exs", "config.exs"], fn file ->
        Igniter.exists?(igniter, Path.join("config", file)) and
          Config.configures_key?(igniter, file, app, path)
      end)
    end

    # Devices without a real-time clock start at 1970. This makes the clock
    # start at the time that the firmware was built instead, so it isn't way
    # off until something like nerves_time sets it. Any erlinit configuration
    # means that the user has looked at it, so nothing is added then.
    defp advance_clock_at_boot(igniter) do
      if configured_in(igniter, :nerves, [:erlinit]) == nil do
        Igniter.update_file(igniter, "config/target.exs", &add_update_clock/1)
      else
        igniter
      end
    end

    # The block is added as text since Sourceror can't insert code that has
    # comments into a file that ends with a comment, which is what the
    # config/target.exs of Nerves projects does. It goes above the trailing
    # `import_config` (commented out or not) so that what's imported can
    # override it.
    defp add_update_clock(source) do
      lines = source |> Rewrite.Source.get(:content) |> String.split("\n")
      index = import_config_index(lines) || length(lines)
      {before, rest} = Enum.split(lines, index)

      content =
        [trim_blank_lines(before), String.trim_trailing(@update_clock), trim_blank_lines(rest)]
        |> Enum.reject(&(&1 == ""))
        |> Enum.join("\n\n")

      Rewrite.Source.update(source, :content, content <> "\n")
    end

    # 0-based index of the first line of the last block of comments and
    # `import_config` lines if the file ends with one
    defp import_config_index(lines) do
      trailing =
        lines
        |> Enum.reverse()
        |> Enum.take_while(&(&1 =~ ~r/^\s*(#.*|import_config\b.*)?$/))

      if Enum.any?(trailing, &(&1 =~ "import_config")) do
        length(lines) - length(trailing)
      end
    end

    defp trim_blank_lines(lines), do: lines |> Enum.join("\n") |> String.trim()

    # -- Other files -----------------------------------------------------------

    defp update_formatter(igniter) do
      if Igniter.exists?(igniter, ".formatter.exs") do
        Igniter.update_elixir_file(igniter, ".formatter.exs", fn zipper ->
          with list when not is_nil(list) <- Zipper.down(zipper),
               list = Zipper.rightmost(list),
               true <- Igniter.Code.List.list?(list),
               {:ok, inputs} <- Igniter.Code.Keyword.get_key(list, :inputs),
               true <- Igniter.Code.List.list?(inputs),
               {:ok, inputs} <- Igniter.Code.List.append_new_to_list(inputs, @iex_exs_path) do
            {:ok, inputs}
          else
            _ -> {:ok, zipper}
          end
        end)
      else
        igniter
      end
    end

    defp update_gitignore(igniter) do
      Igniter.create_or_update_file(igniter, ".gitignore", @gitignore, fn source ->
        content = Rewrite.Source.get(source, :content)

        if content =~ ~r/^\/?\*\.img$/m do
          source
        else
          Rewrite.Source.update(
            source,
            :content,
            String.trim_trailing(content) <> "\n\n" <> @gitignore
          )
        end
      end)
    end

    # -- Companions ------------------------------------------------------------

    # The companion packages configure themselves based on the files that were
    # created above, so their installers have to run after them.
    #
    # Whether an installer is available depends on how this task was started
    # and on which version of the package was fetched:
    #
    # * `mix igniter.install nerves` fetches and compiles everything in
    #   `adds_deps` before running this task, so the installers are found if
    #   the packages have them.
    # * `mix nerves.install` doesn't fetch anything. The dependencies are added
    #   to the mix.exs and the user is told how to run the installers.
    defp install_companions(igniter) do
      {igniter, missing} =
        Enum.reduce(@companions, {igniter, []}, fn {app, _requirement} = dep,
                                                   {igniter, missing} ->
          igniter = Deps.add_dep(igniter, dep, append?: true, on_exists: :skip)
          task = "#{app}.install"

          if Mix.Task.get(task) do
            {Igniter.compose_task(igniter, task), missing}
          else
            {igniter, [app | missing]}
          end
        end)

      case Enum.reverse(missing) do
        [] ->
          igniter

        missing ->
          Igniter.add_notice(igniter, """
          nerves: the installers for #{Enum.map_join(missing, ", ", &to_string/1)} weren't available, so
          these packages were added to mix.exs without their recommended
          configuration. Once they've been fetched, try running:

              mix igniter.install #{Enum.map_join(missing, " ", &to_string/1)}

          If that reports that an installer doesn't exist, see the package's
          documentation for how to configure it.
          """)
      end
    end

    # -- Notices ---------------------------------------------------------------

    defp add_next_steps_notice(igniter, true = _already_nerves?), do: igniter

    defp add_next_steps_notice(igniter, false) do
      Igniter.add_notice(igniter, """
      nerves: your project is now a Nerves project.

      Nerves requires the nerves_bootstrap archive. If you don't have it, run:

          mix archive.install hex nerves_bootstrap

      To build firmware, pick one of the targets in your mix.exs and run:

          export MIX_TARGET=<target>
          mix deps.get
          mix firmware

      See https://nerves.hexdocs.pm/getting-started.html for what to do next.
      """)
    end

    # -- Utilities -------------------------------------------------------------

    defp read(igniter, key \\ :content, path) do
      igniter
      |> Igniter.include_existing_file(path)
      |> Map.fetch!(:rewrite)
      |> Rewrite.source!(path)
      |> Rewrite.Source.get(key)
    end

    defp any_node?(%Zipper{} = zipper, fun) do
      {_quoted, found?} =
        zipper |> Zipper.topmost_root() |> Macro.prewalk(false, &{&1, &2 or fun.(&1)})

      found?
    end

    # Sourceror wraps literals in `:__block__` nodes to hold their metadata
    defp unwrap({:__block__, _, [value]}), do: value
    defp unwrap(value), do: value
  end
else
  defmodule Mix.Tasks.Nerves.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'nerves.install' requires igniter. Please install igniter and try again.

      For more information, see: https://igniter.hexdocs.pm/readme.html#installation
      """)

      exit({:shutdown, 1})
    end
  end
end
