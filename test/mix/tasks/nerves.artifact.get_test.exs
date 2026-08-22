# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.ArtifactGetTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO
  alias Nerves.BuildPlanHelpers

  setup do
    BuildPlanHelpers.reset_plan()
  end

  # Spot check the task. See integration tests for better coverage.

  test "nerves.artifact.get checks for prebuilt artifacts" do
    Mix.Task.reenable("nerves.artifact.get")

    output =
      capture_io(fn ->
        :ok = Mix.Task.run("nerves.artifact.get")
      end)

    assert output =~ "Checking for prebuilt Nerves artifacts..."
  end
end
