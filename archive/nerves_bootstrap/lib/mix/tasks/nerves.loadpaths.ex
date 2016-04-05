defmodule Mix.Tasks.Nerves.Loadpaths do
  use Mix.Task
  alias Nerves.Env

  def run(_args) do
    case Code.ensure_loaded?(Nerves.Env) do
      true ->
        Env.initialize
        try do
          Env.bootstrap
          shell_info
        rescue
          UndefinedFunctionError ->
            Mix.shell.info "Nerves Env needs to be updated"
          e ->
            raise e
        end
      false ->
        Mix.shell.info "Nerves Env not loaded"
    end
  end

  def env(k) do
    k
    |> System.get_env
    |> Path.relative_to_cwd
  end

  def shell_info do
    if System.get_env("NERVES_DEBUG") == "1" do
      Mix.shell.info """
      ------------------
      Nerves Environment
      ------------------
      target:     #{Mix.Project.config[:target]}
      toolchain:  #{env("NERVES_TOOLCHAIN")}
      system:     #{env("NERVES_SYSTEM")}
      """
    end
  end
end
