defmodule Mix.Tasks.Nerves.New do
  use Mix.Task
  import Mix.Generator

  @nerves Path.expand("../../..", __DIR__)
  @version Mix.Project.config[:version]
  @requirement Mix.Project.config[:elixir]
  @shortdoc "Creates a new Nerves application"

  @new [
    {:eex,  "new/config/config.exs",                "config/config.exs"},
    {:eex,  "new/lib/application_name.ex",          "lib/application_name.ex"},
    {:eex,  "new/test/test_helper.exs",             "test/test_helper.exs"},
    {:eex,  "new/test/application_name_test.exs",   "test/application_name_test.exs"},
    {:eex,  "new/rel/vm.args",                      "rel/vm.args"},
    {:text, "new/rel/.gitignore",                   "rel/.gitignore"},
    {:text, "new/.gitignore",                       ".gitignore"},
    {:eex,  "new/mix.exs",                          "mix.exs"},
    {:eex,  "new/README.md",                        "README.md"},
    {:keep, "new/rel",                              "rel"}
  ]

  # Embed all defined templates
  root = Path.expand("../../../templates", __DIR__)

  for {format, source, _} <- @new do
    unless format == :keep do
      @external_resource Path.join(root, source)
      def render(unquote(source)), do: unquote(File.read!(Path.join(root, source)))
    end
  end

  @moduledoc """
  Creates a new Nerves project.
  It expects the path of the project as argument.
      mix nerves.new PATH [--module MODULE] [--app APP]
  A project at the given PATH will be created. The
  application name and module name will be retrieved
  from the path, unless `--module` or `--app` is given.
  ## Options
    * `--app` - the name of the OTP application
    * `--module` - the name of the base module in
      the generated skeleton
    * `--target` - Required. specify the default target to use.

  ## Examples
      mix nerves.new blinky
  Is equivalent to:
      mix nerves.new blinky --module Blinky
  """

  @switches [target: :string, app: :string, module: :string]

  def run([version]) when version in ~w(-v --version) do
    Mix.shell.info "Nerves v#{@version}"
  end

  def run(argv) do
    unless Version.match? System.version, @requirement do
      Mix.raise "Nerves v#{@version} requires at least Elixir v1.2.4.\n " <>
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
    target = opts[:target] || Mix.raise """
    You must specify a default target you would like nerves to use
    Example:
    mix nerves.new blinky --target rpi2
    """
    nerves_path = nerves_path(path, Keyword.get(opts, :dev, false))

    in_umbrella? = in_umbrella?(path)

    binding = [application_name: app,
               application_module: mod,
               bootstrap_vsn: @version,
               nerves_dep: nerves_dep(nerves_path),
               default_target: target,
               in_umbrella: in_umbrella?]

    copy_from path, binding, @new
  end

  defp switch_to_string({name, nil}), do: name
  defp switch_to_string({name, val}), do: name <> "=" <> val

  defp check_application_name!(name, from_app_flag) do
    unless name =~ ~r/^[a-z][\w_]*$/ do
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
    unless name =~ ~r/^[A-Z]\w*(\.[A-Z]\w*)*$/ do
      Mix.raise "Module name must be a valid Elixir alias (for example: Foo.Bar), got: #{inspect name}"
    end
  end

  defp check_module_name_availability!(name) do
    name = Module.concat(Elixir, name)
    if Code.ensure_loaded?(name) do
      Mix.raise "Module name #{inspect name} is already taken, please choose another name"
    end
  end

  defp nerves_dep("deps/nerves"), do: ~s[{:nerves, "~> 0.3.0"}]
  defp nerves_dep(path), do: ~s[{:nerves, path: #{inspect path}, override: true}]

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
    application_name = Keyword.fetch!(binding, :application_name)
    for {format, source, target_path} <- mapping do
      target = Path.join(target_dir,
                         String.replace(target_path, "application_name", application_name))

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
end
