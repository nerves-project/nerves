defmodule ReleaseManager.Plugin.Nerves do
  use ReleaseManager.Plugin

  @vsn1 "/buildroot/output/staging/usr/lib/erlang/lib"
  @vsn2 "/staging/usr/lib/erlang/lib"
  @vm_args ""

  def before_release(%Config{version: version} = config) do
    case System.get_env("NERVES_SYSTEM") do
      nil -> config
      system ->
        info "Modifying release for Nerves System #{Mix.Project.config[:target]}"

        relx_config = config.relx_config

        vm_args_file = '#{File.cwd!}/rel/vm.args'
        vm_args =
          relx_config[:overlay]
          |> IO.inspect
          |> Enum.find(fn(
            {_, ^vm_args_file, _}) -> true
            _ -> false
          end)

        overlay =
          case vm_args do
            nil ->
              default_vm_args =
                Mix.Project.deps_paths[:nerves]
                |> Path.join("template/_iex.vm.args")
                |> String.to_char_list
              [{:copy, default_vm_args, vm_args_file} | relx_config[:overlay]]
            _ -> relx_config[:overlay]
          end
        relx_config
        |> Enum.reject(fn
          {:include_erts, _} -> true
          {:system_libs, _} -> true
          {:overlay, _} -> true
          _ -> false
        end)

        relx_config = [{:include_erts, false} | relx_config]
        relx_config = [{:system_libs, String.to_char_list(system_libs(system))} | relx_config]
        relx_config = [{:overlay, overlay} | relx_config]

        config = %{config | relx_config: relx_config}
    end
  end

  def after_release(_),     do: nil
  def after_package(_),     do: nil
  def after_cleanup(_args), do: nil

  defp system_libs(system),
    do: system <> if File.dir?(system <> @vsn2), do: @vsn2, else: @vsn1
end
