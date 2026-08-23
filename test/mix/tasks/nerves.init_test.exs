# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.InitTest do
  use ExUnit.Case, async: false

  test "nerves.init rejects direct invocation" do
    # Currently, nerves is not clever enough to support code coverage on this path.
    {output, status} =
      System.cmd("mix", ["nerves.init"], cd: File.cwd!(), stderr_to_stdout: true)

    assert status != 0
    assert output =~ "nerves.init is not intended to be invoked directly"
  end
end
