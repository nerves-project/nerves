defmodule Mix.Tasks.Compile.NervesPackage do
  use Mix.Task
  import Mix.Nerves.IO

  require Logger

  @moduledoc """
    Build a Nerves Artifact from a Nerves Package
  """

  @shortdoc "Nerves Package Compiler"
  @recursive true

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

  def bootstrap_check(true), do: :ok

  def bootstrap_check(false) do
    error =
      cond do
        in_umbrella?(File.cwd!()) ->
          """
          Compiling Nerves packages from the top of umbrella projects isn't supported. 
          Please cd into the application directory and try again.
          """

        true ->
          """
          Compiling Nerves packages requires nerves_bootstrap to be started.
          Please ensure that MIX_TARGET is set in your environment and that you have added 
          the proper aliases to your mix.exs file:

            def project do
              [
                # ...
                aliases: [loadconfig: [&bootstrap/1]],
              ]
            end

            defp bootstrap(args) do
              Application.start(:nerves_bootstrap)
              Mix.Task.run("loadconfig", args)
            end
          """
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
