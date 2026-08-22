# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.ArtifactCleanTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO
  alias Nerves.BuildPlanHelpers

  setup do
    BuildPlanHelpers.reset_plan()
  end

  # Spot check the task. See integration tests for better coverage.

  test "nerves.artifact.clean handles projects without Nerves packages" do
    Mix.Task.reenable("nerves.artifact.clean")

    output =
      capture_io(fn ->
        :ok = Mix.Task.run("nerves.artifact.clean", ["--yes"])
      end)

    assert output =~ "No Nerves packages found in the current project."
  end
end
