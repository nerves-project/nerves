defmodule Mix.Tasks.Nerves.Precompile do
  use Mix.Task
  alias Nerves.Env
  import Mix.Nerves.Bootstrap.Utils

  def run(_args) do
    debug_info "Nerves Precompile Start"
    System.put_env("NERVES_PRECOMPILE", "1")
    Mix.Tasks.Deps.Compile.run ["nerves_system"]
    Env.initialize

    if Env.stale? do
      Mix.Tasks.Deps.Compile.run [Env.system.app, "--include-children"]
    else
      debug_info "Nerves Env current"
    end

    System.put_env("NERVES_PRECOMPILE", "0")
    Mix.Task.reenable "deps.precompile"
    debug_info "Nerves Precompile End"
  end
end
