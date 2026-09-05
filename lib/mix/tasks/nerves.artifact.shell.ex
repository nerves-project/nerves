# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.Artifact.Shell do
  @shortdoc "Open a container shell for Nerves package builds"
  @moduledoc """
  Open an interactive container shell for building Nerves packages

  This is useful when modifying or debugging the prebuilt contents of
  Nerves packages. Builds are run using the container provider found
  on your computer or by setting the `NERVES_CONTAINER_TOOL` environment
  variable to `docker`, `podman`, or `container`.

  Nerves does not specify how package artifacts get built. Buildroot, for
  example, uses `make` and has commands like `make menuconfig` and
  `make savedefconfig`. Source changes made in the container are copied
  back to the host when the shell exits.

  IMPORTANT: You can run `mix nerves.artifact.shell` in a Nerves project. Just
  be aware that you're modifying a dependency and any changes may be under
  the `deps` directory.

  Run `mix nerves.artifact.ls` to see the containers created by the Nerves tooling
  and `mix nerves.artifact.purge` to delete them.

  ## Examples

  Building from within a Nerves package:

  ```shell
  $ cd nerves_system_rpi0
  $ mix nerves.artifact.shell

  # In the container now
  nerves@6a5c16134cca:/workspace/build$ make
  ...

  # The way to make the final tarball is package-specific, but
  # this works for nerves_system_br-based projects.
  nerves@6a5c16134cca:/workspace/build$ make system
  ```

  Building a Nerves-aware dependency:

  ```shell
  $ MIX_TARGET=rpi0 mix nerves.artifact.shell nerves_system_rpi0
  ```
  """
  use Mix.Task

  alias Nerves.Container
  alias Nerves.MixUtils
  @impl Mix.Task
  @spec run([String.t()]) :: :ok
  def run(argv) do
    {_opts, args, _invalid} = OptionParser.parse(argv, switches: [])

    build_plan = Nerves.build_plan()

    package = MixUtils.select_package!(build_plan, args)

    {tool, image, dl_dir, unchanged?} =
      Container.prepare_artifact_workspace!(build_plan, package)

    command = if unchanged?, do: ["shell"], else: ["setup", "shell"]
    docker_args = Container.artifact_run_args(build_plan, package, tool, image, dl_dir, command)

    MixUtils.info("""
    Opening shell for #{package.app} with #{tool}

      Work dir:  #{Container.work_dir(package)}
      Downloads: #{dl_dir}

    Source changes will be copied back to #{package.path} when the shell exits.
    See `nerves.artifact.clean`, `nerves.artifact.purge`, and
    `nerves.artifact.build` for cleaning, deleting, and non-interactive builds.
    """)

    _ = MixUtils.interactive_cmd(tool, docker_args)

    MixUtils.info("Syncing source changes from container")
    Container.sync_work_dir(build_plan, tool, package, image)
    MixUtils.info("Done.")

    :ok
  end
end
