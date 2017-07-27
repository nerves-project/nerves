defmodule Mix.Tasks.Nerves.New do
  use Mix.Task
  import Mix.Generator

  @nerves Path.expand("../../../..", __DIR__)

  @nerves_vsn "0.7"
  @bootloader_vsn "0.1"
  @bootstrap_vsn "0.6"
  @runtime_vsn "0.4"

  @requirement Mix.Project.config[:elixir]
  @shortdoc "Creates a new Nerves application"

  @targets [
    "rpi",
    "rpi0",
    "rpi2",
    "rpi3",
    "bbb",
    "linkit",
    "ev3",
    "qemu_arm"
  ]

  @new [
    {:eex,  "new/config/config.exs",                "config/config.exs"},
    {:eex,  "new/lib/app_name.ex",                  "lib/app_name.ex"},
    {:eex,  "new/lib/app_name/application.ex",      "lib/app_name/application.ex"},
    {:eex,  "new/test/test_helper.exs",             "test/test_helper.exs"},
    {:eex,  "new/test/app_name_test.exs",           "test/app_name_test.exs"},
    {:eex,  "new/rel/vm.args",                      "rel/vm.args"},
    {:text, "new/.gitignore",                       ".gitignore"},
    {:eex,  "new/mix.exs",                          "mix.exs"},
    {:eex,  "new/README.md",                        "README.md"},
    {:keep, "new/rel",                              "rel"}
  ]

  # Embed all defined templates
  root = Path.expand("../../../../templates", __DIR__)

  for {format, source, _} <- @new do
    unless format == :keep do
      @external_resource Path.join(root, source)
      def render(unquote(source)), do: unquote(File.read!(Path.join(root, source)))
    end
  end

  @moduledoc """
  Creates a new Nerves project.
  It expects the path of the project as argument.

      mix nerves.new PATH [--module MODULE] [--app APP] [--target TARGET]

  A project at the given PATH will be created. The
  application name and module name will be retrieved
  from the path, unless `--module` or `--app` is given.

  An `--app` option can be given in order to name the OTP
  application for the project.

  A `--module` option can be given in order to name the
  modules in the generated code skeleton.

  ## Examples

      mix nerves.new blinky

  Is equivalent to:

      mix nerves.new blinky --module Blinky

  `--target` is optional. If unspecified, the project will be generated to
  support all official Nerves systems. Passing `--target` limits the generated
  project to a single system, or multiple systems.

  For a list of supported targets visit
  https://hexdocs.pm/nerves/targets.html#supported-targets-and-systems

  ## Examples

  Generate a project that only supports Raspberry Pi 3

      mix nerves.new blinky --target rpi3

  Generate a project that supports Raspberry Pi 3 and Raspberry Pi Zero

      mix nerves.new blinky --target rpi3 --target rpi0


  # Network options

  `--cookie` - Specify the cookie to set for the vm.args.
    Defaults to a randomly generated string

  """

  @switches [app: :string, module: :string, target: :keep, cookie: :string]

  def run([version]) when version in ~w(-v --version) do
    Mix.shell.info "Nerves v#{@bootstrap_vsn}"
  end

  def run(argv) do
    unless Version.match? System.version, @requirement do
      Mix.raise "Nerves v#{@bootstrap_vsn} requires at least Elixir #{@requirement}.\n " <>
                "You have #{System.version}. Please update accordingly"
    end

    {opts, argv} =
      case OptionParser.parse(argv, strict: @switches) do
        {opts, argv, []} ->
          {opts, argv}
        {_opts, _argv, [switch | _]} ->
          Mix.raise "Invalid option: " <> switch_to_string(switch)
      end

    case argv do
      [] ->
        Mix.Task.run "help", ["nerves.new"]
      [path|_] ->
        app = opts[:app] || Path.basename(Path.expand(path))
        check_application_name!(app, !!opts[:app])
        mod = opts[:module] || Macro.camelize(app)
        check_module_name_validity!(mod)
        check_module_name_availability!(mod)

        run(app, mod, path, opts)
    end
  end

  def run(app, mod, path, opts) do
    System.delete_env("MIX_TARGET")

    nerves_path = nerves_path(path, Keyword.get(opts, :dev, false))
    in_umbrella? = in_umbrella?(path)

    targets =
      (opts || [])
      |> Keyword.get_values(:target)

    Enum.each(targets, fn(target) ->
      unless target in @targets do
        targets = Enum.join(@targets, "\n")
        Mix.raise """
        Unknown target #{inspect target}
        Supported targets
        #{targets}
        """
      end
    end)

    targets = if targets == [], do: @targets, else: targets
    cookie = opts[:cookie] || random_string(64)
    binding = [app_name: app,
               app_module: mod,
               bootstrap_vsn: @bootstrap_vsn,
               bootloader_vsn: @bootloader_vsn,
               runtime_vsn: @runtime_vsn,
               elixir_req: @requirement,
               nerves_dep: nerves_dep(nerves_path),
               in_umbrella: in_umbrella?,
               targets: targets,
               cookie: cookie]

    copy_from path, binding, @new
    # Parallel installs
    install? = Mix.shell.yes?("\nFetch and install dependencies?")
    File.cd!(path, fn ->
      extra =
        if install? && Code.ensure_loaded?(Hex) do
          cmd("mix deps.get")
          cmd("mix nerves.release.init")
          []
        else
          ["  $ mix deps.get", "  $ mix release.init"]
        end

      print_mix_info(path, extra)
    end)
  end

  def recompile(regex) do
    if Code.ensure_loaded?(Regex) and function_exported?(Regex, :recompile!, 1) do
      apply(Regex, :recompile!, [regex])
    else
      regex
    end
  end

  defp cmd(cmd) do
    Mix.shell.info [:green, "* running ", :reset, cmd]
    case Mix.shell.cmd(cmd, [quiet: true]) do
      0 ->
        true
      _ ->
        Mix.shell.error [:red, "* error ", :reset, "command failed to execute, " <>
          "please run the following command again after installation: \"#{cmd}\""]
        false
    end
  end

  defp print_mix_info(path, extra) do
    command = ["$ cd #{path}"] ++ extra
    Mix.shell.info """
    Your Nerves project was created successfully.

    You should now pick a target. See https://hexdocs.pm/nerves/targets.html#content
    for supported targets. If your target is on the list, set `MIX_TARGET`
    to its tag name:

    For example, for the Raspberry Pi 3 you can either
      $ export MIX_TARGET=rpi3
    Or prefix `mix` commands like the following:
      $ MIX_TARGET=rpi3 mix firmware

    If you will be using a custom system, update the `mix.exs`
    dependencies to point to desired system's package.

    Now download the dependencies and build a firmware archive:
      #{Enum.join(command, "\n")}
      $ mix deps.get
      $ mix firmware

    If your target boots up using an SDCard (like the Raspberry Pi 3),
    then insert an SDCard into a reader on your computer and run:
      $ mix firmware.burn

    Plug the SDCard into the target and power it up. See target documentation
    above for more information and other targets.
    """
  end

  defp switch_to_string({name, nil}), do: name
  defp switch_to_string({name, val}), do: name <> "=" <> val

  defp check_application_name!(name, from_app_flag) do
    unless name =~ recompile(~r/^[a-z][\w_]*$/) do
      extra =
        if !from_app_flag do
          ". The application name is inferred from the path, if you'd like to " <>
          "explicitly name the application then use the `--app APP` option."
        else
          ""
        end

      Mix.raise "Application name must start with a letter and have only lowercase " <>
                "letters, numbers and underscore, got: #{inspect name}" <> extra
    end
  end

  defp check_module_name_validity!(name) do
    unless name =~ recompile(~r/^[A-Z]\w*(\.[A-Z]\w*)*$/) do
      Mix.raise "Module name must be a valid Elixir alias (for example: Foo.Bar), got: #{inspect name}"
    end
  end

  defp check_module_name_availability!(name) do
    name = Module.concat(Elixir, name)
    if Code.ensure_loaded?(name) do
      Mix.raise "Module name #{inspect name} is already taken, please choose another name"
    end
  end

  defp nerves_dep("deps/nerves"), do: ~s[{:nerves, "~> #{@nerves_vsn}", runtime: false}]
  defp nerves_dep(path), do: ~s[{:nerves, path: #{inspect path}, runtime: false, override: true}]

  defp nerves_path(path, true) do
    absolute = Path.expand(path)
    relative = Path.relative_to(absolute, @nerves)

    if absolute == relative do
      Mix.raise "--dev project must be inside Nerves directory"
    end

    relative
    |> Path.split
    |> Enum.map(fn _ -> ".." end)
    |> Path.join
  end

  defp nerves_path(_path, false) do
    "deps/nerves"
  end

  defp copy_from(target_dir, binding, mapping) when is_list(mapping) do
    app_name = Keyword.fetch!(binding, :app_name)
    for {format, source, target_path} <- mapping do
      target = Path.join(target_dir,
                         String.replace(target_path, "app_name", app_name))

      case format do
        :keep ->
          File.mkdir_p!(target)
        :text ->
          create_file(target, render(source))
        :append ->
          append_to(Path.dirname(target), Path.basename(target), render(source))
        :eex  ->
          contents = EEx.eval_string(render(source), binding, file: source)
          create_file(target, contents)
      end
    end
  end

  defp append_to(path, file, contents) do
    file = Path.join(path, file)
    File.write!(file, File.read!(file) <> contents)
  end

  defp in_umbrella?(app_path) do
    try do
      umbrella = Path.expand(Path.join [app_path, "..", ".."])
      File.exists?(Path.join(umbrella, "mix.exs")) &&
        Mix.Project.in_project(:umbrella_check, umbrella, fn _ ->
          path = Mix.Project.config[:apps_path]
          path && Path.expand(path) == Path.join(umbrella, "apps")
        end)
    catch
      _, _ -> false
    end
  end

  defp random_string(length) do
    :crypto.strong_rand_bytes(length) |> Base.encode64 |> binary_part(0, length)
  end
end
