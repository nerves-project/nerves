defmodule Mix.Tasks.Nerves.Env do
  use Mix.Task
  import Mix.Nerves.Bootstrap.Utils

  @switches [info: :boolean]

  def run(argv) do
    {opts, _, _} = OptionParser.parse(argv, switches: @switches)
    Mix.Tasks.Deps.Compile.run ["nerves", "--include-children"]
    Nerves.Env.start()
    if opts[:info], do: print_env()
  end

  def print_env() do
    Mix.shell.info """
    ---------------------------
    Nerves Environment Packages
    ---------------------------
    """
    Nerves.Env.packages
    |> Enum.each(&print_pkg/1)
    System.put_env("NERVES_DEBUG", "1")
    Mix.Tasks.Nerves.Loadpaths.run []
  end

  defp print_pkg(pkg) do
    {provider, _} = pkg.provider
    Mix.shell.info """
    Pkg:      #{pkg.app}
    Vsn:      #{pkg.version}
    Type:     #{pkg.type}
    Provider: #{provider}
    """
  end

end
