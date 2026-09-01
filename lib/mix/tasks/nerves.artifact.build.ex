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
  what went wrong. Configuration changes made in the shell are copied out of
  the container when the shell exits.

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
  @switches [path: :string]

  @impl Mix.Task
  @spec run([String.t()]) :: :ok
  def run(argv) do
    {_opts, args, _invalid} = OptionParser.parse(argv, switches: @switches)

    build_plan = Nerves.build_plan()

    package = MixUtils.select_package!(build_plan, args)

    build_artifact(build_plan, package)
  end

  defp build_artifact(build_plan, package) do
    # The build process is expected to create all of the downloads. Not 100% sure
    # this makes sense, but this is currently the case.

    artifact_dl_dir = package.download_path
    archive_paths = Enum.map(package.downloads, fn download -> download.archive_path end)
    {tool, image, dl_dir} = Container.prepare_artifact_workspace!(build_plan, package)
    docker_args = Container.artifact_run_args(build_plan, package, tool, image, dl_dir)

    MixUtils.info("Building artifact for #{package.app} with #{tool}")
    MixUtils.info("  Work dir:       #{Container.work_dir(package)}")
    MixUtils.info("  Download dir:   #{dl_dir}")
    MixUtils.info("  Package output: #{artifact_dl_dir}")

    case MixUtils.interactive_cmd(tool, docker_args) do
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
