defmodule ReleaseManager.Plugin.Nerves do
  use ReleaseManager.Plugin

  def before_release(%Config{} = config) do
    case System.get_env("NERVES_SYSTEM") do
      nil -> config
      system ->
        info "Modifying release for Nerves System #{system}"
        relx_config = config.relx_config
        |> Enum.reject(fn
          {:include_erts, _} -> true
          {:system_libs, _} -> true
          _ -> false
        end)
        relx_config = [{:include_erts, false} | relx_config]
        relx_config = [{:system_libs, "#{system}/buildroot/output/staging/usr/lib/erlang/lib"} | relx_config]
        %{config | relx_config: relx_config}
    end
  end

  def after_release(_) do
  end

  def after_package(_) do
  end

  def after_cleanup(_args) do
  end
end
