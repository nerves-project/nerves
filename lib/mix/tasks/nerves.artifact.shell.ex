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
  `make savedefconfig`. Files are stored in the container. To copy
  them out, run `mix nerves.artifact.sync`.

  IMPORTANT: You can run `mix nerves.artifact.shell` in a Nerves project. Just
  be aware that you're modifying a dependency and any changes may be under
  the `deps` directory.

  Run `mix nerves.artifact.ls` to see the containers created by the Nerves tooling
  and `mix nerves.artifact.clean` to delete them.

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
  nerves@6a5c16134cca:/workspace/build$ make system NERVES_ARTIFACT_NAME=$NERVES_ARTIFACT_NAME
  ```

  Building a Nerves-aware dependency:

  ```shell
  $ MIX_TARGET=rpi0 mix nerves.artifact.shell nerves_system_rpi0
  ```
  """
  use Mix.Task

  alias Nerves.Container
  alias Nerves.MixUtils
  alias Nerves.Paths

  @impl Mix.Task
  @spec run([String.t()]) :: :ok
  def run(argv) do
    {_opts, args, _invalid} = OptionParser.parse(argv, switches: [])

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

    # Set $NERVES_ARTIFACT_NAME to the first of these without the extension.
    # Not recommended for new Nerves packages.
    archive_paths = Enum.map(package.downloads, fn download -> download.archive_path end)
    nerves_artifact_name = Regex.replace(~r/\.tar.*/, Path.basename(hd(archive_paths)), "")

    dl_dir = Paths.download_dir()
    File.mkdir_p!(dl_dir)

    term = System.get_env("TERM") || "xterm-256color"
    tool = Container.tool()
    image = Container.shell_container_image(tool)

    # Set up and populate the single work directory
    Container.ensure_work_dir(tool, package)
    Container.populate_work_dir(build_plan, tool, package)

    work_mounts = Container.work_mount_args(tool, package)
    shell_script = build_shell_script(package)

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
          image,
          "/bin/sh",
          "-lc",
          shell_script
        ]

    MixUtils.info("""
    Opening shell for #{package.app} with #{tool}

      Work dir:  #{Container.work_dir(package)}
      Downloads: #{dl_dir}
      Artifact name: #{nerves_artifact_name}

    Exit shell and use `mix nerves.artifact.sync #{package.app}` to copy configuration
    changes back to the host. See `nerves.artifact.clean` and `nerves.artifact.build`
    for deleting the container and non-interactive builds.
    """)

    _ = InteractiveCmd.cmd(tool, docker_args)
    :ok
  end

  defp build_shell_script(pkg) do
    """
    #{Container.memory_check_script()}
    #{pkg.shell_setup_script}
    echo ""
    echo "Build directory: /workspace/build"
    echo "Package source:  /workspace/#{pkg.app}"
    echo ""
    exec /bin/bash
    """
  end
end
