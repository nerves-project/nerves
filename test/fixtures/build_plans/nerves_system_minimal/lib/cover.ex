# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Cover do
  @moduledoc false
  use Mix.Task

  @impl Mix.Task
  @spec run([String.t()]) :: :ok
  def run(args) do
    [path, export, task_name | task_args] = args
    cover = cover(path, export)

    task =
      String.split(task_name, ".")
      |> Enum.map(&Macro.camelize/1)
      |> concat_mix_tasks()
      |> Module.concat()

    task.run(task_args)

    cover.()
    :ok
  end

  defp concat_mix_tasks(list), do: ["Mix", "Tasks"] ++ list

  defp cover(path, export) do
    compile_path = Path.join([path, "_build", "test", "lib", "nerves", "ebin"])

    Mix.Tasks.Test.Coverage.start(compile_path,
      output: Path.join(path, "cover"),
      export: export
    )
  end
end
