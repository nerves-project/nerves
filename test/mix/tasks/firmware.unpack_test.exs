# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Firmware.UnpackTest do
  use ExUnit.Case, async: false

  alias Nerves.BuildPlanHelpers

  setup do
    BuildPlanHelpers.reset_plan()
  end

  # Spot check the task. See integration tests for better coverage.

  @tag :tmp_dir
  test "firmware.unpack reports missing firmware on the host", %{tmp_dir: tmp_dir} do
    Mix.Task.reenable("firmware.unpack")
    firmware = Path.join(tmp_dir, "missing.fw")

    error =
      assert_raise Mix.Error, fn ->
        Mix.Task.run("firmware.unpack", ["--fw", firmware])
      end

    assert error.message =~ "No firmware specified and unspecified target"
    assert error.message =~ "using `--fw`"
  end
end
