defmodule Mix.Tasks.Nerves.Artifact.Details do
  @shortdoc "Prints Nerves artifact details"
  @moduledoc """
  Prints Nerves artifact details.

  This displays various details.

  ## Examples

      $ mix nerves.artifact.details nerves_system_rpi0

  If the command is called without the package name,
  `Nerves.Project.config()[:app]` will be used by default.
  """
  use Mix.Task

  import Mix.Nerves.IO

  alias Nerves.Artifact

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
        Mix.shell().info("Version:            #{package.version}")
        Mix.shell().info("Checksum:           #{Artifact.checksum(package)}")
        # TODO - Find a way to get this from Artifact
        short_checksum_length = 7

        Mix.shell().info(
          "Checksum Short      #{Artifact.checksum(package, short: short_checksum_length)}"
        )

        Mix.shell().info("Name:               #{Artifact.name(package)}")
        Mix.shell().info("Download Name:      #{Artifact.download_name(package)}")

        Mix.shell().info(
          "Download File Name: #{Artifact.download_name(package)}#{Artifact.ext(package)}"
        )

        Mix.shell().info("Download Path:      #{Artifact.download_path(package)}")

        Mix.shell().info(
          "Sites:              #{inspect(Keyword.get(package.config, :artifact_sites, []))}"
        )

        Mix.shell().info("Base Directory:     #{Artifact.base_dir()}")
        Mix.shell().info("Path:               #{Artifact.dir(package)}")
        Mix.shell().info("Build Path:         #{Artifact.build_path(package)}")
      end

    debug_info("Nerves.Artifact.Details end")
  end
end
