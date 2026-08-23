# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.FirmwareTest do
  use ExUnit.Case, async: false

  alias Nerves.BuildPlanHelpers

  setup do
    BuildPlanHelpers.reset_plan()
  end

  # Spot check the task. See integration tests for better coverage.

  test "firmware fails on host" do
    Mix.Task.reenable("firmware")

    assert_raise Mix.Error, fn -> Mix.Task.run("firmware") end
  end
end
