defmodule Mix.Tasks.Nerves.Loadpaths do
  @moduledoc false
  use Mix.Task
  import Mix.Nerves.IO

  @impl Mix.Task
  def run(_args) do
    unless System.get_env("NERVES_PRECOMPILE") == "1" do
      debug_info("Loadpaths Start")

      Mix.Task.run("nerves.precompile", ["--no-loadpaths"])

      try do
        nerves_env_info()
        Mix.Task.run("nerves.env", [])
        Nerves.Env.bootstrap()
        Mix.Project.clear_deps_cache()
        env_info()
      rescue
        e ->
          reraise e, __STACKTRACE__
      end

      debug_info("Loadpaths End")
    end
  end

  defp env(k) do
    case System.get_env(k) do
      unset when unset == nil or unset == "" -> "unset"
      set -> Path.relative_to_cwd(set)
    end
  end

  defp env_info() do
    debug_info("Environment Variable List", """
      target:     #{Mix.target()}
      toolchain:  #{env("NERVES_TOOLCHAIN")}
      system:     #{env("NERVES_SYSTEM")}
      app:        #{env("NERVES_APP")}
    """)
  end
end
