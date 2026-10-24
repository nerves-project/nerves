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

  # nerves_precompiled is a dependency of the project, not of nerves, so it is
  # absent in most projects.
  @compile {:no_warn_undefined, NervesPrecompiled}

  @impl Mix.Task
  def run(_args) do
    [task_name | task_args] = System.argv()

    cond do
      task_name == "nerves.init" ->
        Mix.raise("nerves.init is not intended to be invoked directly.")

      task_name == "do" ->
        # Guess that at least one command is going to require Nerves integration
        Nerves.export_env()
        precompiled()

      skip_nerves_integration?(task_name) ->
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
        precompiled()
    end
  end

  # Projects opt in by depending on nerves_precompiled. nerves_bootstrap has
  # compiled only nerves and its children at this point, so the library is
  # compiled here, before Mix compiles the rest, and then asked to install
  # matching builds for what remains.
  defp precompiled() do
    if Enum.any?(Mix.Dep.cached(), &(&1.app == :nerves_precompiled)) do
      Mix.Tasks.Deps.Compile.run(["nerves_precompiled"])

      Code.prepend_path(
        Path.join([Mix.Project.build_path(), "lib", "nerves_precompiled", "ebin"])
      )

      if Code.ensure_loaded?(NervesPrecompiled), do: NervesPrecompiled.run()
    end

    :ok
  end

  defp skip_nerves_integration?(task_name) do
    # This needs to be specific since some other repositories have
    # nerves. mix tasks and those should get the integration since we
    # don't know what they'll do.
    task_name in [
      "format",
      "help",
      "local",
      "nerves.discover",
      "nerves.info",
      "nerves.deps.get",
      "nerves.loadpaths",
      "nerves.system.shell"
    ] or
      Enum.any?(
        [
          "nerves.artifact.",
          "hex.",
          "local."
        ],
        &String.starts_with?(task_name, &1)
      )
  end

  defp task_name_to_existing_module(name) do
    parts = name |> String.split(".") |> Enum.map(&String.capitalize/1)
    mod = Module.concat([Mix, Tasks | parts])

    case Code.ensure_loaded(mod) do
      {:module, _} -> mod
      {:error, _} -> Mix.raise("The task \"#{name}\" could not be found")
    end
  end
end
