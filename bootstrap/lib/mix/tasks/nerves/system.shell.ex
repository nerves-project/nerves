defmodule Mix.Tasks.Nerves.System.Shell do
  use Mix.Task

  @shortdoc "Enter a shell to configure a custom system"

  @moduledoc """
  Open a shell in a system's build directory.
  In order to make the experience as similar as possible, we attach to a Docker
  container on non-Linux platforms and run a sub-shell on Linux.

  ## Examples

  Configure the system for the current project's target:

      mix nerves.system.shell

  """

  @no_nerves_dep_error """
  Nerves dependency not found in current Mix project.
  Make sure you run this task from a Nerves-based project or the source directory of a custom Nerves system.
  """

  @no_system_pkg_error """
  Unable to locate a relevant Nerves system package.
  Make sure you run this task from a Nerves-based project or the source directory of a custom Nerves system.
  """

  @doc false
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
      e in Mix.Error ->
        if String.starts_with?(e.message, "Unknown dependency nerves for environment") do
          Mix.raise(@no_nerves_dep_error)
        end
    end

    pkg = Nerves.Env.system()
    if is_nil(pkg), do: Mix.raise(@no_system_pkg_error)

    provider = case :os.type do
      {_, :linux} -> Nerves.Package.Providers.Local
      _ -> Nerves.Package.Providers.Docker
    end
    provider.system_shell(pkg)

    # Set :user back to the real one
    Process.register(user, :user)

  end

end
