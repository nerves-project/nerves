# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.SystemShellTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Nerves.BuildPlanHelpers

  setup do
    BuildPlanHelpers.reset_plan()
  end

  test "prints the artifact commands" do
    Mix.Task.reenable("nerves.system.shell")

    output = capture_io(fn -> Mix.Task.run("nerves.system.shell") end)

    assert output =~ "nerves.system.shell task is now nerves.artifact.shell"
  end
end
