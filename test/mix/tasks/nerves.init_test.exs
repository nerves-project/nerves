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

  test "the precompiled hook is a no-op when the project does not depend on elixir_precompiled" do
    refute Enum.any?(Mix.Dep.cached(), &(&1.app == :elixir_precompiled))

    original_argv = System.argv()
    System.argv(["compile"])

    try do
      assert Mix.Tasks.Nerves.Init.run([]) == :ok
    after
      System.argv(original_argv)
    end
  end
end
