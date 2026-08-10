# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.Artifact.Sync do
  @shortdoc "Sync changed files from the container work directory"
  @moduledoc """
  Copy files from a Nerves system's container work directory back to the host

  After making configuration changes in a `mix nerves.artifact.shell` session
  (e.g., `make menuconfig` followed by `make savedefconfig`), use this task
  to copy the updated files back to your working directory.

  This overwrites host files with the versions from the work directory's
  `pkg/` subdirectory. Use `git diff` afterwards to review what changed.

  `MIX_TARGET` must be set so that target-specific dependencies are
  available. When no package name is given, the task auto-selects if
  there is exactly one Nerves artifact dependency.

  ## Examples

      $ MIX_TARGET=rpi0 mix nerves.artifact.sync
      $ MIX_TARGET=rpi0 mix nerves.artifact.sync test_system_rpi0
  """
  use Mix.Task

  alias Nerves.Container
  alias Nerves.MixUtils

  @impl Mix.Task
  @spec run([String.t()]) :: :ok
  def run(args) do
    {_opts, args, _invalid} = OptionParser.parse(args, switches: [])

    build_plan = Nerves.build_plan()

    package =
      case args do
        [name | _] -> Enum.find(build_plan.packages, fn info -> to_string(info.app) == name end)
        _ -> List.last(build_plan.packages)
      end

    if package == nil do
      Mix.raise("""
      Couldn't find package
      """)
    end

    tool = Container.tool()

    MixUtils.info("Syncing files from work dir to #{package.dest}")

    Container.sync_work_dir(tool, package)

    MixUtils.info("Done. Use `diff` to review changes.")
  end
end
