# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.DiscoverTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  test "nerves.discover forwards the timeout" do
    Mix.Task.reenable("nerves.discover")

    # Wait 1.234s since nerves_discovery currently has a 1 second minimum timeout
    output =
      capture_io(fn ->
        Mix.Task.run("nerves.discover", ["--timeout", "1234"])
      end)

    assert output =~ "Discovering Nerves devices (waiting up to 1234ms)..."
    # Don't check whether devices are found or not, since they might be.
  end
end
