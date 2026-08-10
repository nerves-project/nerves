# SPDX-FileCopyrightText: 2022 Jon Carstens
# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.Init do
  # This is an internal task used by the Nerves tooling to
  # set up the system environment to properly run build tools.

  @moduledoc false
  use Mix.Task

  alias Nerves.MixUtils

  @impl Mix.Task
  def run(_args) do
    [task_name | task_args] = System.argv()

    cond do
      task_name == "nerves.init" ->
        Mix.raise("nerves.init is not intended to be invoked directly.")

      String.starts_with?(task_name, "nerves.") ->
        # Short circuit Mix compilation to run Nerves tasks without compiling
        # any non-Nerves project dependencies so that the tools can affect
        # cross-compilation. This avoids chicken-and-egg scenarios where you
        # want to use the Nerves tooling to clean up or change artifacts, but
        # to run the tools the default Mix way, you'd have to wait for the
        # dependencies supplying the artifacts to build.
        task_mod = task_name_to_existing_module(task_name)
        task_mod.run(task_args)
        System.halt()

      true ->
        Nerves.export_env()
        log_key_vars()
    end
  end

  defp task_name_to_existing_module(name) do
    parts = name |> String.split(".") |> Enum.map(&String.capitalize/1)
    mod = Module.concat([Mix, Tasks | parts])

    case Code.ensure_loaded(mod) do
      {:module, _} -> mod
      {:error, _} -> Mix.raise("The task \"#{name}\" could not be found")
    end
  end

  defp log_key_vars() do
    _ =
      for var <- ~w(NERVES_SYSTEM NERVES_TOOLCHAIN CROSSCOMPILE CC) do
        case System.get_env(var) do
          nil -> :ok
          val -> MixUtils.info("  #{var}=#{val}")
        end
      end

    :ok
  end
end
