# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.Loadpaths do
  @shortdoc false
  @moduledoc false

  use Mix.Task

  @impl Mix.Task
  @spec run([String.t()]) :: no_return()
  def run(_argv) do
    Mix.raise("""
    Update Nerves Bootstrap

    You are using Nerves 2 with a version of Nerves Bootstrap that only knows about Nerves 1.
    Please upgrade it by running:

    mix local.nerves
    """)
  end
end
