defmodule Mix.Tasks.Nerves.Precompile do
  use Mix.Task
  import Mix.Nerves.Bootstrap.Utils

  def run(_args) do
    debug_info "Precompile Start"

    System.put_env("NERVES_PRECOMPILE", "1")
    Mix.Tasks.Nerves.Env.run []
    Mix.Tasks.Deps.Compile.run [to_string(Nerves.Env.system.app), "--include-children"]
    Mix.Task.reenable "deps.compile"
    System.put_env("NERVES_PRECOMPILE", "0")

    Mix.Tasks.Nerves.Loadpaths.run []
    debug_info "Precompile End"
  end
end
