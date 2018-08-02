defmodule Nerves do
  use Mix.Releases.Plugin

  def before_assembly(release, _opts) do
    if nerves_env_loaded?() do
      vm_args = Map.get(release.profile, :vm_args) || "rel/vm.args"

      profile =
        release.profile
        |> Map.put(:dev_mode, false)
        |> Map.put(:include_src, false)
        |> Map.put(:include_erts, System.get_env("ERL_LIB_DIR"))
        |> Map.put(:vm_args, vm_args)

      %{release | profile: profile}
    else
      release
    end
  end

  def after_assembly(%Release{} = release, _opts) do
    release
  end

  def before_package(%Release{} = release, _opts) do
    release
  end

  def after_package(%Release{} = release, _opts) do
    release
  end

  def after_cleanup(_args, _opts) do
    :noop
  end

  def version, do: unquote(Mix.Project.config()[:version])
  def elixir_version, do: unquote(System.version())

  def nerves_env_loaded? do
    System.get_env("NERVES_ENV_BOOTSTRAP") != nil
  end
end
