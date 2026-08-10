# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.Artifact.Build do
  @shortdoc "Build a Nerves artifact"
  @moduledoc """
  Build a Nerves artifact using a container tool (Apple container, Docker, or Podman).

  Compiles the system and creates a `.tar.gz` archive suitable for
  distribution. The result is placed in the downloads directory and
  extracted into the local cache.

  Source files and build dependencies are copied into a work directory
  that is mounted into the container. On Linux the work directory is a
  bind mount under `_build/`; on macOS it is a Docker volume.

  `MIX_TARGET` must be set so that target-specific dependencies are
  available. When no package name is given, the task auto-selects if
  there is exactly one Nerves artifact dependency.

  ## Examples

      $ MIX_TARGET=rpi0 mix nerves.artifact.build
      $ MIX_TARGET=rpi0 mix nerves.artifact.build test_system_rpi0
  """
  use Mix.Task

  alias Nerves.Container
  alias Nerves.MixUtils
  alias Nerves.Paths

  @switches [path: :string]

  @impl Mix.Task
  @spec run([String.t()]) :: :ok
  def run(argv) do
    {_opts, args, _invalid} = OptionParser.parse(argv, switches: @switches)

    build_plan = Nerves.build_plan()

    package =
      case args do
        [app | _] -> Enum.find(build_plan.packages, fn info -> to_string(info.app) == app end)
        [] -> List.last(build_plan.packages)
      end

    cond do
      package == nil and build_plan.packages == [] ->
        Mix.raise("""
        No Nerves packages found.

        This could be due to the mix target not being set to include the Nerves
        packages. It's currently set to `#{Mix.target()}`.
        """)

      package == nil ->
        Mix.raise("""
        Nerves package #{hd(args)} not found.

        The following are available for mix target `#{Mix.target()}`:

        #{Enum.map_join(build_plan.packages, "\n", fn info -> to_string(info.app) end)}
        """)

      true ->
        :ok
    end

    build_artifact(build_plan, package)
  end

  defp build_artifact(build_plan, package) do
    # The build process is expected to create all of the downloads. Not 100% sure
    # this makes sense, but this is currently the case.

    dl_dir = Paths.download_dir()
    artifact_dl_dir = package.download_path
    archive_paths = Enum.map(package.downloads, fn download -> download.archive_path end)
    rel_download_paths = Enum.map(archive_paths, &Path.relative_to(&1, artifact_dl_dir))
    rel_artifact_dl_dir = Path.relative_to(artifact_dl_dir, dl_dir)

    # Set $NERVES_ARTIFACT_NAME to the first of these without the extension.
    # Not recommended for new Nerves packages.
    nerves_artifact_name = Regex.replace(~r/\.tar.*/, Path.basename(hd(archive_paths)), "")

    # Ensure the download directory exists if this is the first build with Nerves
    File.mkdir_p!(artifact_dl_dir)

    build_script =
      [
        Container.memory_check_script(),
        package.build_script,
        "cp #{Enum.join(rel_download_paths, " ")} /workspace/dl/#{rel_artifact_dl_dir}"
      ]
      |> Enum.join("\n")

    term = System.get_env("TERM") || "xterm-256color"
    tool = Container.tool()

    # Set up the single work directory (volume on macOS, bind mount on Linux)
    Container.ensure_work_dir(tool, package)
    Container.populate_work_dir(build_plan, tool, package)

    work_mounts = Container.work_mount_args(tool, package)

    docker_args =
      [
        "run",
        "--rm",
        "-it"
      ] ++
        Container.container_user_args(tool) ++
        Container.resource_args(tool) ++
        [
          "--env",
          "NERVES_BR_DL_DIR=/workspace/dl",
          "--env",
          "TERM=#{term}",
          "--env",
          "NERVES_ARTIFACT_NAME=#{nerves_artifact_name}"
        ] ++
        work_mounts ++
        [
          # Shared download cache, intentionally read-write
        ] ++
        Container.download_mount_args(tool, dl_dir) ++
        [
          "-w",
          "/workspace/build",
          Container.default_docker_image(),
          "/bin/sh",
          "-lc",
          build_script
        ]

    MixUtils.info("Building artifact for #{package.app} with #{tool}")
    MixUtils.info("  Work dir:       #{Container.work_dir(package)}")
    MixUtils.info("  Download dir:   #{dl_dir}")
    MixUtils.info("  Package output: #{artifact_dl_dir}")

    case InteractiveCmd.cmd(tool, docker_args) do
      {_, 0} ->
        if not Enum.all?(archive_paths, &File.regular?/1) do
          Mix.raise("""
          Container build finished, but one or more artifact outputs
          weren't found.

          Expected paths:

          #{Enum.join(archive_paths, "\n")}
          """)
        end

        MixUtils.info("Artifact build succeeded.")

      {_, status} ->
        Mix.raise("Container build failed with status #{status}")
    end
  end
end
