# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.ArtifactShellTest do
  use ExUnit.Case, async: false

  alias Nerves.BuildPlanHelpers

  setup do
    BuildPlanHelpers.reset_plan()
  end

  # Spot check the task

  test "nerves.artifact.shell raises when no Nerves packages are available" do
    Mix.Task.reenable("nerves.artifact.shell")

    assert_raise Mix.Error, ~r/No Nerves packages found/, fn ->
      Mix.Task.run("nerves.artifact.shell")
    end
  end
end
