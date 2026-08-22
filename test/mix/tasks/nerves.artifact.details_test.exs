# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.ArtifactDetailsTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO
  alias Nerves.BuildPlanHelpers

  setup do
    BuildPlanHelpers.reset_plan()
  end

  # Spot check the task. See integration tests for better coverage.

  test "nerves.artifact.details handles projects without Nerves artifact packages" do
    Mix.Task.reenable("nerves.artifact.details")

    output =
      capture_io(fn ->
        Mix.Task.run("nerves.artifact.details")
      end)

    assert output =~ "No Nerves artifact packages found in project deps."
  end
end
