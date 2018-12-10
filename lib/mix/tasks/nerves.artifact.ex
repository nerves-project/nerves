defmodule Mix.Tasks.Nerves.Artifact do
  use Mix.Task

  import Mix.Nerves.IO

  require Logger

  @moduledoc """
  Create an artifact for a specified Nerves package.

  ## Command line options

    * `--path <path>`: The location where you want the archive to be placed.
      Default: `$NERVES_DL_DIR || ~/.nerves/dl`

  ## Examples

      $ mix nerves.artifact nerves_system_rpi0

  If the command is called without the package name,
  `Nerves.Project.config()[:app]` will be used by default.

      $ mix nerves.artifact --path /tmp

  """

  @shortdoc "Nerves create artifact"
  @recursive true

  @switches [path: :string]

  @impl true
  def run(argv) do
    # We need to make sure the the Nerves env has been set up.
    # This allows the task to be called from a project level that
    # does not include aliases to nerves_bootstrap
    Mix.Task.run("nerves.precompile", [])

    {package_name, argv} =
      case argv do
        [] ->
          {to_string(Mix.Project.config()[:app]), argv}

        ["-" <> _arg | _] ->
          {to_string(Mix.Project.config()[:app]), argv}

        [package_name | argv] ->
          {package_name, argv}
      end

    debug_info("Nerves.Artifact start")

    {opts, _, _} = OptionParser.parse(argv, switches: @switches)

    package_name = String.to_atom(package_name)

    package = Nerves.Env.package(package_name)
    toolchain = Nerves.Env.toolchain()

    cond do
      package == nil ->
        Mix.raise("Could not find Nerves package #{package_name} in env")

      Nerves.Artifact.stale?(package) ->
        Mix.raise("Your package sources are stale. Please run mix compile first.")

      true ->
        Nerves.Artifact.archive(package, toolchain, opts)
    end

    debug_info("Nerves.Artifact end")
  end
end
