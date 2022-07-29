defmodule Mix.Tasks.Nerves.Artifact.Details do
  @shortdoc "Prints Nerves artifact details"
  @moduledoc """
  Prints Nerves artifact details.

  This displays various artifact names/information.

  ## Examples

      $ mix nerves.artifact.details nerves_system_rpi0

  If the command is called without the package name,
  `Nerves.Project.config()[:app]` will be used by default.
  """
  use Mix.Task

  import Mix.Nerves.IO

  require Logger

  @recursive true

  @impl Mix.Task
  def run(argv) do
    # We need to make sure the Nerves env has been set up.
    # This allows the task to be called from a project level that
    # does not include aliases to nerves_bootstrap
    Mix.Task.run("nerves.precompile", [])

    {package_name, _argv} =
      case argv do
        [] ->
          {to_string(Mix.Project.config()[:app]), argv}

        ["-" <> _arg | _] ->
          {to_string(Mix.Project.config()[:app]), argv}

        [package_name | argv] ->
          {package_name, argv}
      end

    debug_info("Nerves.Artifact.Details start")

    package_name = String.to_atom(package_name)

    package = Nerves.Env.package(package_name)

    _ =
      if is_nil(package) do
        Mix.raise("Could not find Nerves package #{package_name} in env")
      else
        Mix.shell().info("Name:               #{Nerves.Artifact.name(package)}")
        Mix.shell().info("Download Name:      #{Nerves.Artifact.download_name(package)}")

        Mix.shell().info(
          "Download File Name: #{Nerves.Artifact.download_name(package)}#{Nerves.Artifact.ext(package)}"
        )

        Mix.shell().info("Download Path:      #{Nerves.Artifact.download_path(package)}")
        Mix.shell().info("Checksum:           #{Nerves.Artifact.checksum(package)}")
      end

    debug_info("Nerves.Artifact.Details end")
  end
end
