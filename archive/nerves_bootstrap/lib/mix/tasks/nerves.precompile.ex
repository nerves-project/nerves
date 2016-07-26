defmodule Mix.Tasks.Nerves.Precompile do
  use Mix.Task
  alias Nerves.Env
  import Mix.Nerves.Bootstrap.Utils

  def run(_args) do
    debug_info "Nerves Precompile Start"
    System.put_env("NERVES_PRECOMPILE", "1")
    Mix.Tasks.Deps.Compile.run ["nerves", "--include-children"]
    Nerves.Env.start
    System.put_env("NERVES_PRECOMPILE", "0")

    Mix.Tasks.Nerves.Loadpaths.run []
    debug_info "Nerves Precompile End"
  end
end
