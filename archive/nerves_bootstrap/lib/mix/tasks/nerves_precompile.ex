defmodule Mix.Tasks.Nerves.Precompile do
  use Mix.Task
  alias Nerves.Env

  require Logger

  def run(_args) do
    Mix.shell.info "Nerves Precompile Started"

    Mix.Task.reenable "deps.compile"
    Mix.Task.run "deps.compile", ["nerves_system"]
    #Mix.Task.run "deps.loadpaths"
    #Mix.Task.reenable "deps.loadpaths"
    Env.initialize

    Mix.Task.reenable "deps.check"
    Mix.Task.run "deps.check", ["--no-compile"]

    # TODO JS: Determine if the compiler needs to be forced to run. (Extensions Changed)
    # This will have to write out to a compile manifest with the list of ext
    #  that are compiled into the system image
    if Env.stale? do
      Mix.Task.reenable "deps.compile"
      Mix.Task.run "deps.compile", [Env.system.app, "--include-children"]
    else
      Mix.shell.info "Nerves Env current"
    end

    Env.stop
    Mix.shell.info "Nerves Precompile Ended"
  end
end
