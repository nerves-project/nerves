defmodule Mix.Tasks.Nerves.Loadpaths do
  use Mix.Task
  import Mix.Nerves.IO

  def run(_args) do
    unless System.get_env("NERVES_PRECOMPILE") == "1" do
      debug_info "Loadpaths Start"
      case Code.ensure_compiled?(Nerves.Env) do
        true ->
          try do
            Mix.Tasks.Nerves.Env.run []
            Nerves.Env.bootstrap
            env_info()
          rescue
            e ->
              reraise e, System.stacktrace()
          end
        false ->
          debug_info "Env not loaded"
      end
      debug_info "Loadpaths End"
    end
  end

  def env(k) do
    case System.get_env(k) do
      unset when unset == nil or unset == "" -> "unset"
      set -> Path.relative_to_cwd(set)
    end
  end

  def env_info do
    debug_info "Environment Variable List", """
      target:     #{Mix.Project.config[:target] || "unset"}
      toolchain:  #{env("NERVES_TOOLCHAIN")}
      system:     #{env("NERVES_SYSTEM")}
      app:        #{env("NERVES_APP")}
    """
  end
end
