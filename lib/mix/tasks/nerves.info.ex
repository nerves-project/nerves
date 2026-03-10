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

  @switches [target: :string]

  @impl Mix.Task
  def run(argv) do
    debug_info("Info Start")
    {opts, _, _} = OptionParser.parse(argv, switches: @switches)
    Nerves.Env.disable()

    if target = opts[:target] do
      Nerves.Env.change_target(target)
    end

    Mix.Tasks.Nerves.Env.run(["--info", "--disable"])
    Mix.shell().info("Nerves:           #{Nerves.version()}")
    Mix.shell().info("Nerves Bootstrap: #{bootstrap_version()}")
    Mix.shell().info("Elixir:           #{System.version()}")
    Nerves.Env.enable()
    debug_info("Info End")
  end

  defp bootstrap_version() do
    archives_path = Mix.path_for(:archives)
    prefix = Path.join(archives_path, "nerves_bootstrap-")

    case Path.wildcard("#{prefix}*") do
      [] -> "not installed"
      [entry | _] -> String.trim_leading(entry, prefix)
    end
  end
end
