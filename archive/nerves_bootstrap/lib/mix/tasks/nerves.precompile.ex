defmodule Mix.Tasks.Nerves.Precompile do
  use Mix.Task
  alias Nerves.Env

  require Logger

  def run(_args) do
    Mix.Tasks.Deps.Compile.run ["nerves_system"]

    case Mix.Task.run "deps.check", ["--no-compile"] do
      :noop -> :ok
      _ -> Mix.Task.reenable "deps.check"
    end

    if Env.stale? do
      Mix.Tasks.Deps.Compile.run [Env.system.app, "--include-children"]
    else
      Mix.shell.info "Nerves Env current"
    end
    Mix.Tasks.Nerves.Loadpaths.run "nerves.loadpaths"
    Mix.Task.reenable "deps.precompile"

  end
end
