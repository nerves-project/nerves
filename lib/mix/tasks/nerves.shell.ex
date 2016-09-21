defmodule Mix.Tasks.Nerves.Shell do
  use Mix.Task

  @shortdoc "Launch a Nerves shell"

  @moduledoc """
  Start a Nerves shell for a target or package.

  ### Package Shell
    mix nerves.shell pkg nerves_system_rpi3

  """

  def run(argv) do
    {_, args, _} = OptionParser.parse(argv, switches: [])

    case args do
      ["pkg" | opts] -> pkg_shell(opts)
    end

  end

  def pkg_shell([pkg | _opts]) do
    Nerves.Env.package(pkg)
    |> Nerves.Package.shell
  end
end
