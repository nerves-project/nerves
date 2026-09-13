# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.EnvTest do
  use ExUnit.Case, async: false

  alias Nerves.BuildPlanHelpers
  alias Nerves.Env

  setup do
    BuildPlanHelpers.reset_plan()
  end

  test "firmware_path/0" do
    path = Path.join([Mix.Project.build_path(), "nerves", "images", "nerves.fw"])
    assert Env.firmware_path() == path
  end
end
