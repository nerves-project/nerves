defmodule Nerves do
  use Mix.Releases.Plugin

  def before_assembly(release, _opts) do
    if nerves_env_loaded? do
      project_config = Mix.Project.config
      profile =
        release.profile
        |> Map.put(:dev_mode, false)
        |> Map.put(:output_dir, Path.join([project_config[:build_path], Mix.env, "rel"]))
        |> Map.put(:include_src, false)
        |> Map.put(:include_erts, System.get_env("ERL_LIB_DIR"))
        |> Map.put(:include_system_libs, System.get_env("ERL_SYSTEM_LIB_DIR"))
        |> Map.put_new(:vm_args, "rel/vm.args")
      %{release | profile: profile}
    else
      release
    end
  end

  def version,        do: unquote(Mix.Project.config[:version])
  def elixir_version, do: unquote(System.version)

  def nerves_env_loaded? do
    System.get_env("NERVES_PRECOMPILE") != nil
  end
end
