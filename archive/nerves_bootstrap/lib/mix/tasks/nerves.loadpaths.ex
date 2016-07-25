defmodule Mix.Tasks.Nerves.Loadpaths do
  use Mix.Task

  import Mix.Nerves.Bootstrap.Utils
  alias Nerves.Env

  def run(_args) do
    unless System.get_env("NERVES_PRECOMPILE") == "1" do
      case Code.ensure_compiled?(Nerves.Env) do
        true ->
          Env.initialize
          try do
            Env.bootstrap
            debug_info "Nerves Env loaded"
            env_info
          rescue
            UndefinedFunctionError ->
              debug_info "Nerves Env needs to be updated"
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
    ------------------
    Nerves Environment
    ------------------
    target:     #{Mix.Project.config[:target]}
    toolchain:  #{env("NERVES_TOOLCHAIN")}
    system:     #{env("NERVES_SYSTEM")}
    app:        #{env("NERVES_APP")}
    """
  end
end
