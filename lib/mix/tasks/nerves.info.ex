defmodule Mix.Tasks.Nerves.Info do
  @shortdoc "Prints Nerves information"

  @moduledoc """
  Prints Nerves system information.

      mix nerves.info

  """
  use Mix.Task
  import Mix.Nerves.IO

  @switches [target: :string]

  @impl Mix.Task
  def run(argv) do
    debug_info("Info Start")
    {opts, _, _} = OptionParser.parse(argv, switches: @switches)
    Nerves.Env.disable()

    if target = opts[:target] do
      Nerves.Env.change_target(target)
    end

    Mix.Tasks.Nerves.Env.run(["--info", "--disable"])
    Mix.shell().info("Nerves:           #{Nerves.version()}")
    Mix.shell().info("Nerves Bootstrap: #{Nerves.Bootstrap.version()}")
    Mix.shell().info("Elixir:           #{System.version()}")
    Nerves.Env.enable()
    debug_info("Info End")
  end
end
