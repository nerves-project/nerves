defmodule Mix.Tasks.Nerves.Info do
  use Mix.Task
  import Mix.Nerves.IO

  @shortdoc "Prints Nerves information"

  @moduledoc """
  Prints Nerves system information.
      mix nerves.info
  """

  @switches [target: :string]

  def run(argv) do
    debug_info "Info Start"
    {opts, _, _} = OptionParser.parse(argv, switches: @switches)
    Nerves.Env.disable
    if target = opts[:target] do
      Nerves.Env.change_target(target)
    end
    Mix.Tasks.Nerves.Env.run(["--info", "--disable"])
    Mix.shell.info "Nerves:           #{Nerves.version}"
    Mix.shell.info "Nerves Bootstrap: #{Nerves.Bootstrap.version}"
    Mix.shell.info "Elixir:           #{Nerves.elixir_version}"
    Nerves.Env.enable
    debug_info "Info End"
  end
end
