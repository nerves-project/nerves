defmodule Mix.Tasks.Nerves.Env do
  @moduledoc false
  use Mix.Task
  import Mix.Nerves.IO

  @switches [info: :boolean, disable: :boolean]

  @impl Mix.Task
  def run(argv) do
    debug_info("Env Start")
    {opts, _, _} = OptionParser.parse(argv, switches: @switches)

    if opts[:disable] do
      # This is the same code as Nerves.Env.disable/0, but I can't call that
      # because we're about to load it immediately below. I also can't call it
      # after it's loaded below because the act of compiling the nerves dep
      # calls deps.precompile, which causes the system to get compiled unless
      # Nerves.Env is disabled, which is what I'm trying to do here. :&
      # This could probably be solved by moving Nerves.Env into nerves_bootstrap
      System.put_env("NERVES_ENV_DISABLED", "1")
    else
      System.delete_env("NERVES_ENV_DISABLED")
    end

    # TODO: Remove this as it should be handled when bootstrapping this tooling
    #       into the current running project. Leave it here for now
    unless Code.ensure_loaded?(Nerves.Env) do
      _ = Mix.Tasks.Deps.Loadpaths.run(["--no-compile"])

      Mix.Tasks.Deps.Compile.run(["nerves", "--include-children"])
    end

    _ = Nerves.Env.start()
    debug_info("Env End")
    if opts[:info], do: print_env()
  end

  defp print_env() do
    System.put_env("NERVES_DEBUG", "1")
    debug_info("Environment Package List")

    case Nerves.Env.packages() do
      [] -> Mix.shell().info("  No packages found")
      packages -> Enum.each(packages, &print_pkg/1)
    end

    Mix.Tasks.Nerves.Loadpaths.run([])
  end

  defp print_pkg(pkg) do
    Mix.shell().info("""
      Pkg:         #{pkg.app}
      Vsn:         #{pkg.version}
      Type:        #{pkg.type}
      BuildRunner: #{inspect(pkg.build_runner)}
    """)
  end
end
