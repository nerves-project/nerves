# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.Artifact.Shell do
  @shortdoc "Open a container shell for Nerves system builds"
  @moduledoc """
  Open an interactive container shell for a Nerves system build.

  Starts a container (using Apple container, Docker, or Podman) and drops you into a shell
  in the build directory. The shell image includes Elixir so that Mix tasks
  can be run from inside the container. This is useful for debugging build
  issues or running `make menuconfig`.

  Source files and build dependencies are copied into a work directory
  that is mounted into the container. On Linux the work directory is a
  bind mount under `_build/`; on macOS it is a Docker volume. Changes
  made to files in `/workspace/<pkg_name>/` (e.g., `make savedefconfig`) are
  preserved. Use `mix nerves.artifact.sync` to copy them back to the host.

  The build state in `/workspace/build/` persists across sessions.
  Before opening the shell, Nerves refreshes the build directory setup so
  commands like `make menuconfig` and `make` work immediately.

  `MIX_TARGET` must be set so that target-specific dependencies are
  available. When no package name is given, the task auto-selects if
  there is exactly one Nerves artifact dependency.

  ## Examples

      $ MIX_TARGET=rpi0 mix nerves.artifact.shell
      $ MIX_TARGET=rpi0 mix nerves.artifact.shell test_system_rpi0
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
          "TERM=#{term}"
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

    MixUtils.info("Opening shell for #{package.app} with #{tool}")
    MixUtils.info("  Work dir:  #{Container.work_dir(package)}")
    MixUtils.info("  Downloads: #{dl_dir}")
    MixUtils.info("")

    MixUtils.info(
      "Use `mix nerves.artifact.sync #{package.app}` to copy changes back to the host."
    )

    case InteractiveCmd.cmd(tool, docker_args) do
      {_, 0} -> :ok
      {_, _status} -> :ok
    end
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
