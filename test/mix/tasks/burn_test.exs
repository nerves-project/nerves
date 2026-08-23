# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.BurnTest do
  use ExUnit.Case, async: false

  alias Nerves.BuildPlanHelpers

  setup do
    BuildPlanHelpers.reset_plan()
  end

  # Spot check the task. See integration tests for better coverage.

  @tag :tmp_dir
  test "burn rejects a missing firmware file", %{tmp_dir: tmp_dir} do
    Mix.Task.reenable("burn")
    firmware = Path.join(tmp_dir, "missing.fw")

    error =
      assert_raise Mix.Error, fn ->
        Mix.Task.run("burn", ["--firmware", firmware])
      end

    assert error.message == "The firmware file #{firmware} does not exist"
  end
end
