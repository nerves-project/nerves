# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Firmware.ImageTest do
  use ExUnit.Case, async: false

  alias Nerves.BuildPlanHelpers

  setup do
    BuildPlanHelpers.reset_plan()
  end

  # Spot check the task. See integration tests for better coverage.

  test "firmware.image builds firmware before creating the image" do
    Mix.Task.reenable("firmware")
    Mix.Task.reenable("firmware.image")

    error = assert_raise Mix.Error, fn -> Mix.Task.run("firmware.image") end

    assert error.message =~ "mix firmware requires a Mix target to be set"
  end
end
