defmodule Mix.Tasks.Nerves.Loadpaths do
  use Mix.Task
  import Mix.Nerves.Bootstrap.Utils

  def run(_args) do
    unless System.get_env("NERVES_PRECOMPILE") == "1" do
      case Code.ensure_compiled?(Nerves.Env) do
        true ->
          try do
            Mix.Tasks.Nerves.Env.run []
            Nerves.Env.bootstrap
            env_info()
          rescue
            e ->
              raise e
          end
        false ->
          debug_info "Nerves Env not loaded"
      end
    end
  end

  def env(k) do
    k
    |> System.get_env
    |> Path.relative_to_cwd
  end

  def env_info do
    debug_info """
    ----------------------------
    Nerves Environment Variables
    ----------------------------
    target:     #{Mix.Project.config[:target]}
    toolchain:  #{env("NERVES_TOOLCHAIN")}
    system:     #{env("NERVES_SYSTEM")}
    app:        #{env("NERVES_APP")}
    """
  end
end
