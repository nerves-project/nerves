defmodule Mix.Tasks.Nerves.Env do
  use Mix.Task
  import Mix.Nerves.IO

  @switches [info: :boolean]

  def run(argv) do
    debug_info "Env Start"
    {opts, _, _} = OptionParser.parse(argv, switches: @switches)
    unless Code.ensure_compiled?(Nerves.Env) do
      Mix.Tasks.Deps.Compile.run ["nerves", "--include-children"]
    end
    Nerves.Env.start()
    debug_info "Env End"
    if opts[:info], do: print_env()
  end

  def print_env() do
    System.put_env("NERVES_DEBUG", "1")
    debug_info "Environment Package List"
    case Nerves.Env.packages do
      [] ->       Mix.shell.info "  No packages found"
      packages -> Enum.each(packages, &print_pkg/1)
    end

    Mix.Tasks.Nerves.Loadpaths.run []
  end

  defp print_pkg(pkg) do
    Mix.shell.info """
      Pkg:      #{pkg.app}
      Vsn:      #{pkg.version}
      Type:     #{pkg.type}
      Provider: #{inspect pkg.provider}
    """
  end

end
