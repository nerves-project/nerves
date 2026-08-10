# SPDX-FileCopyrightText: 2022 Jon Carstens
# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.Deps.Get do
  @moduledoc false
  use Mix.Task

  # This is only used by the Nerves v1 integration

  @impl Mix.Task
  def run(_argv) do
    Mix.Task.run("nerves.artifact.get", [])
  end
end
