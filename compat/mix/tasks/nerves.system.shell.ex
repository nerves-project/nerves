# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.System.Shell do
  @moduledoc false
  use Mix.Task

  # This is only used by the Nerves v1 integration

  @impl Mix.Task
  def run(_argv) do
    Mix.shell().info("""
    nerves.system.shell task is now nerves.artifact.shell.

    Please see `mix help` to see all of the `nerves.artifact.*` tasks since
    Nerves v2 adds many commands to help build and manage Nerves artifacts.

    The main ones for building are `nerves.artifact.build`, `nerves.artifact.shell`
    and `nerves.artifact.clean`. If you would prefer a different container image,
    specify a path to a custom `Dockerfile` in your `mix.exs`'s `nerves` configuration
    under the `Dockerfile` key.
    """)

    :ok
  end
end
