defmodule Mix.Tasks.Nerves.Loadpaths do
  use Mix.Task
  alias Nerves.Env

  def run(_args) do
    unless System.get_env("NERVES_PRECOMPILE") == "1" do
      case Code.ensure_compiled?(Nerves.Env) do
        true ->
          Env.initialize
          try do
            Env.bootstrap
            Mix.shell.info "Nerves Env loaded"
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
      app:        #{env("NERVES_APP")}
      """
    end
  end
end
