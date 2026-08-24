# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.Artifact.Build do
  @shortdoc "Build a Nerves artifact"
  @moduledoc """
  Build a Nerves artifact in a container

  This is used to build Nerves packages in between tagged releases.
  Builds are run using the container provider found
  on your computer or by setting the `NERVES_CONTAINER_TOOL` environment
  variable to `docker`, `podman`, or `container`.

  If this step fails, you can run `mix nerves.artifact.shell` to investigate
  what went wrong. Use `mix nerves.artifact.sync` to copy configuration changes
  out of the container.

  Run `mix nerves.artifact.ls` to see the containers created by the Nerves tooling
  and `mix nerves.artifact.clean` to delete them.

  ## Examples

  Building from within a Nerves package:

  ```shell
  $ cd nerves_system_rpi0
  $ mix nerves.artifact.build
  # On success, the resulting tarball will be in your ~/.nerves/dl directory.
  ```

  Building a Nerves-aware dependency:

  ```shell
  $ MIX_TARGET=rpi0 mix nerves.artifact.build nerves_system_rpi0
  # On success, the resulting tarball will be in your ~/.nerves/dl directory
  # and will be found when you run `MIX_TARGET=rpi0 mix firmware` the next
  # time.
  ```
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
    rel_artifact_dl_dir = Path.relative_to(artifact_dl_dir, dl_dir)

    # Ensure the download directory exists if this is the first build with Nerves
    File.mkdir_p!(artifact_dl_dir)

    term = System.get_env("TERM") || "xterm-256color"
    tool = Container.tool()
    image = Container.package_image!(tool, package)

    # Set up the single work directory (volume on macOS, bind mount on Linux)
    MixUtils.info("Preparing container workspace...")
    Container.ensure_work_dir(tool, package)
    Container.populate_work_dir(build_plan, tool, package, image)

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
          "NERVES_ARTIFACT_APP=#{package.app}",
          "--env",
          "NERVES_ARTIFACT_VERSION=#{package.version}",
          "--env",
          "NERVES_ARTIFACT_SOURCE_FINGERPRINT=#{package.source_fingerprint}",
          "--env",
          "NERVES_ARTIFACT_DIR=/workspace/dl/#{rel_artifact_dl_dir}",
          "--env",
          "NERVES_HOST_TUPLE=#{Nerves.TargetTuple.host_string(build_plan.config[:host_tuple])}"
        ] ++
        work_mounts ++
        [
          # Shared download cache, intentionally read-write
        ] ++
        Container.download_mount_args(tool, dl_dir) ++
        [
          "-w",
          "/workspace/build",
          image
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
