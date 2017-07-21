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

  def run(_argv) do

    # TODO: Make sure the current project has a nerves dependency

    # Don't pre-compile so that we can configure the system before building it
    # for the first time.
    Mix.Task.run("nerves.env", ["--disable"])

    # We unregister :user so that the process currently holding fd 0 (stdin)
    # can't send an error message to the console when we steal it.
    user = Process.whereis(:user)
    Process.unregister(:user)

    provider = case :os.type do
      {_, :linux} -> Nerves.Package.Providers.Local
      _ -> Nerves.Package.Providers.Docker
    end
    provider.system_shell(Nerves.Env.system())

    # Set :user back to the real one
    Process.register(user, :user)

  end

end
