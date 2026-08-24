# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.Artifact.Sync do
  @shortdoc "Sync changed files from the container work directory"
  @moduledoc """
  Copy files from a Nerves packages's container work directory back to the host

  Run this after making configuration changes with `mix nerves.artifact.shell`.
  For example, if you run `make savedefconfig` in a Buildroot-based Nerves
  package, it will update the `nerves_defconfig` in the container. This
  copies that file back out.

  If you're modifying a Nerves package that's included via a dependency,
  you'll probably need to set `MIX_TARGET` for that dependency to be
  available.

  ## Examples

  When working inside the Nerves package:

  ```shell
  $ cd nerves_system_rpi0
  $ mix nerves.artifact.sync
  ```

  When running in a Nerves project:

  ```shell
  $ cd my_nerves_project
  $ MIX_TARGET=rpi0 mix nerves.artifact.sync test_system_rpi0
  ```
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

      Here's everything that's available:

      #{packages_to_string(build_plan.packages)}
      """)
    end

    tool = Container.tool()
    image = Container.package_image!(tool, package)

    MixUtils.info("Syncing files from work dir to #{package.path}")

    Container.sync_work_dir(tool, package, image)

    MixUtils.info("Done. Use `git diff` to review changes.")
  end

  defp packages_to_string(packages) do
    Enum.map_join(packages, ", ", fn pkg -> to_string(pkg.app) end)
  end
end
