defmodule Mix.Tasks.Compile.NervesPackage do
  @shortdoc "Nerves Package Compiler"
  @moduledoc """
  Build a Nerves Artifact from a Nerves Package
  """
  use Mix.Task
  import Mix.Nerves.IO

  require Logger

  @recursive true

  @impl Mix.Task
  def run(_args) do
    debug_info("Compile.NervesPackage start")

    if Nerves.Env.enabled?() do
      config = Mix.Project.config()

      bootstrap_started?()
      |> bootstrap_check()

      Nerves.Env.ensure_loaded(Mix.Project.config()[:app])

      package = Nerves.Env.package(config[:app])
      toolchain = Nerves.Env.toolchain()

      ret =
        if Nerves.Artifact.stale?(package) do
          Nerves.Artifact.build(package, toolchain)
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

  @doc false
  def bootstrap_check(true), do: :ok

  def bootstrap_check(false) do
    error =
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

    Mix.raise(error)
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
