# SPDX-FileCopyrightText: 2017 Justin Schneck
# SPDX-FileCopyrightText: 2022 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.Info do
  @shortdoc "Prints Nerves information"

  @moduledoc """
  Prints Nerves system information.

      mix nerves.info

  """
  use Mix.Task
  import Mix.Nerves.IO

  @impl Mix.Task
  def run(_args) do
    debug_info("Info Start")
    Nerves.Env.disable()

    Mix.Tasks.Nerves.Env.run(["--info", "--disable"])
    Mix.shell().info("Nerves:           #{Nerves.version()}")
    Mix.shell().info("Nerves Bootstrap: #{Nerves.Bootstrap.version()}")
    Mix.shell().info("Elixir:           #{System.version()}")

    Nerves.Env.enable()
    debug_info("Info End")
  end
end
