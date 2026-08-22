# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.ArtifactLsTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO
  alias Nerves.BuildPlanHelpers

  setup do
    BuildPlanHelpers.reset_plan()
  end

  # Spot check the task. See integration tests for better coverage.

  test "nerves.artifact.ls prints the artifact cache state" do
    Mix.Task.reenable("nerves.artifact.ls")

    output =
      capture_io(fn ->
        Mix.Task.run("nerves.artifact.ls")
      end)

    assert output =~ "Cached artifacts"
    assert output =~ "Downloads"
    assert output =~ "Container build volumes"
  end
end
