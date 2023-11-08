defmodule Mix.Tasks.Compile.NervesPackage do
  @shortdoc "Nerves Package Compiler"
  @moduledoc """
  Compile a Nerves package into a local artifact

  This is only intended to be used by Nerves systems and toolchains
  and configured in thier mix.exs files. It should not be used manually
  when compiling a Nerves project. See `mix firmware` instead.
  """
  use Mix.Task
  import Mix.Nerves.IO

  require Logger

  @recursive true

  @impl Mix.Task
  def run(_args) do
    debug_info("Compile.NervesPackage start")

    if Nerves.Env.enabled?() do
      bootstrap_check!()

      package =
        case Nerves.Env.ensure_loaded(Mix.Project.config()[:app]) do
          {:ok, package} -> package
          {:error, err} -> Mix.raise(err)
        end

      toolchain = Nerves.Env.toolchain()

      ret =
        if Nerves.Artifact.stale?(package) do
          _ = Nerves.Artifact.build(package, toolchain)
          :ok
        else
          :noop
        end

      debug_info("Compile.NervesPackage end")
      ret
    else
      debug_info("Compile.NervesPackage disabled")
      :noop
    end
  end

  defp bootstrap_check!() do
    cond do
      bootstrap_started?() ->
        :ok

      not bootstrap_installed?() ->
        Mix.raise("""
        Compiling Nerves packages requires the nerves_bootstrap archive which is missing
        from the Elixir version currently in use (#{System.version()}).

        Please install it with:

          mix archive.install hex nerves_bootstrap
        """)

      true ->
        Mix.raise(
          """
          Compiling Nerves packages requires nerves_bootstrap to be started, which ought to
          happen in your generated `config.exs`. Please ensure that MIX_TARGET is set in your environment.
          """ <>
            if in_umbrella?(File.cwd!()) do
              """

              When compiling from an Umbrella project you must also ensure:

              * You are compiling from an application directory, not the root of the Umbrella

              * The Umbrella config (/config/config.exs) imports the generated Nerves config from your
              Nerves application (import_config "../apps/your_nerves_app/config/config.exs")

              """
            else
              ""
            end
        )
    end
  end

  defp bootstrap_installed?() do
    Mix.path_for(:archives)
    |> Path.join("*")
    |> Path.wildcard()
    |> Enum.any?(&(&1 =~ ~r/nerves_bootstrap/))
  end

  defp bootstrap_started?() do
    Application.started_applications()
    |> Enum.map(&Tuple.to_list/1)
    |> Enum.map(&List.first/1)
    |> Enum.member?(:nerves_bootstrap)
  end

  defp in_umbrella?(app_path) do
    umbrella = Path.expand(Path.join([app_path, "..", ".."]))
    mix_path = Path.join(umbrella, "mix.exs")
    apps_path = Path.join(umbrella, "apps")

    File.exists?(mix_path) && File.exists?(apps_path)
  end
end
