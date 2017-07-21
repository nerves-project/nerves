defmodule Mix.Tasks.Nerves.Precompile do
  use Mix.Task
  import Mix.Nerves.IO

  def run(_args) do
    debug_info "Precompile Start"

    # Note: We have to directly use the environment variable here instead of
    # calling Nerves.Env.enabled?/0 because the nerves.precompile step happens
    # before the nerves dependency is compiled, which is where Nerves.Env
    # currently lives. This would be improved by moving Nerves.Env to
    # nerves_bootstrap.
    unless System.get_env("NERVES_ENV_DISABLED") do
      System.put_env("NERVES_PRECOMPILE", "1")
      Mix.Tasks.Nerves.Env.run []
      parent = Mix.Project.config[:app]
      system_app = Nerves.Env.system.app
      {m, f, a} =
        if parent == system_app do
          Mix.Tasks.Deps.Compile.run [Nerves.Env.toolchain.app, "--include-children"]
          {Mix.Tasks.Compile, :run, [["--no-deps-check"]]}
        else
          system_app_name = to_string(system_app)
          {Mix.Tasks.Deps.Compile, :run, [[system_app_name, "--include-children"]]}
        end
      apply(m, f, a)
      Mix.Task.reenable "deps.compile"
      Mix.Task.reenable "compile"
      System.put_env("NERVES_PRECOMPILE", "0")

      Mix.Tasks.Nerves.Loadpaths.run []
    end

    debug_info "Precompile End"
  end
end
