defmodule Mix.Tasks.Nerves.Env do
  use Mix.Task

  @switches [info: :boolean]

  def run(argv) do
    {opts, _, _} = OptionParser.parse(argv, switches: @switches)
    Mix.Tasks.Deps.Compile.run ["nerves", "--include-children"]
    # Env moved to :nerves, try to start it otherwise, compile
    #  :nerves_system and call initialize
    try do
      Nerves.Env.start()
    rescue
      UndefinedFunctionError ->
        Mix.Tasks.Deps.Compile.run ["nerves_system", "--include-children"]
        Nerves.Env.initialize()
    end
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
