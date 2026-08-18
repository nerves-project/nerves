# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.LoadpathsTest do
  use ExUnit.Case, async: true

  test "raises when invoked" do
    # This exercises the case where the user has an old version of Nerves
    # Bootstrap installed and they need to update it.
    assert_raise Mix.Error, fn ->
      Mix.Task.run("nerves.loadpaths")
    end
  end
end
