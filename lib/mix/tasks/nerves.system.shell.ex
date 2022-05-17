defmodule Mix.Tasks.Nerves.System.Shell do
  @shortdoc "Enter a shell to configure a custom system"

  @moduledoc """
  Open a shell in a system's build directory.

  In order to make the experience as similar as possible, we attach to a Docker
  container on non-Linux platforms and run a sub-shell on Linux.

  ## Examples

  Configure the system for the current project's target:

      mix nerves.system.shell

  """
  use Mix.Task

  @standard_error_message """
  Make sure you run this task from a Nerves-based project or the source directory of a custom Nerves system.
  Also, set the MIX_TARGET environment variable to allow mix.exs to know which custom system dependency to use.
  """

  @no_nerves_dep_error """
  Nerves dependency not found in current Mix project.
  #{@standard_error_message}
  """

  @no_system_pkg_error """
  Unable to locate a relevant Nerves system package.
  #{@standard_error_message}
  """

  @no_mix_target_error """
  MIX_TARGET environment variable not set or set to "host".
  #{@standard_error_message}
  """

  @doc false
  @spec run([String.t()]) :: :ok
  def run(_argv) do
    # We unregister :user so that the process currently holding fd 0 (stdin)
    # can't send an error message to the console when we steal it.
    user = Process.whereis(:user)
    Process.unregister(:user)

    # Start disabled so that we can configure the system before building it
    # for the first time.
    try do
      Mix.Task.run("nerves.env", ["--disable"])
    rescue
      e ->
        case e do
          %Mix.Error{message: "Unknown dependency nerves for environment " <> _env} ->
            Mix.raise(@no_nerves_dep_error)

          _ ->
            reraise(e, __STACKTRACE__)
        end
    end

    pkg = Nerves.Env.system()

    if is_nil(pkg) do
      case Mix.target() do
        :host -> Mix.raise(@no_mix_target_error)
        _ -> Mix.raise(@no_system_pkg_error)
      end
    end

    {build_runner, _opts} = pkg.build_runner

    build_runner.system_shell(pkg)

    # Set :user back to the real one
    Process.register(user, :user)

    :ok
  end
end
