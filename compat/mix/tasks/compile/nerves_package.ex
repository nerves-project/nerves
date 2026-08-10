# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Compile.NervesPackage do
  @shortdoc "No-op compiler for legacy Nerves packages"
  @moduledoc """
  No-op compiler that satisfies old Nerves packages which include
  `:nerves_package` in their `compilers` list.

  In nerves, artifacts are downloaded pre-built, so this compiler
  does nothing.

  Use `mix nerves.artifact.build` to build a package.
  """

  use Mix.Task.Compiler

  @impl true
  @spec run(any()) :: :ok
  def run(_args) do
    :ok
  end
end
