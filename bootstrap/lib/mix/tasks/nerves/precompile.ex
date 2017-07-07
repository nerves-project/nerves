defmodule Mix.Tasks.Nerves.Precompile do
  use Mix.Task
  import Mix.Nerves.IO

  def run(_args) do
    debug_info "Precompile Start"

    System.put_env("NERVES_PRECOMPILE", "1")
    Mix.Tasks.Nerves.Env.run []
    system_app = Nerves.Env.system.app
    {m, f, a} =
      if parent == system_app do
        {Mix.Tasks.Compile, :run, [["--no-deps-check"]]}
      else
        system_app_name = to_string(system_app)
        {Mix.Tasks.Deps.Compile, :run, [[system_app_name, "--include-children"]]}
      end
    apply(m, f, a)
    Mix.Task.reenable "deps.compile"
    System.put_env("NERVES_PRECOMPILE", "0")

    Mix.Tasks.Nerves.Loadpaths.run []
    debug_info "Precompile End"
  end
end
