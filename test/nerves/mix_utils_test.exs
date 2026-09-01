# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.MixUtilsTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Nerves.EnvHelpers
  alias Nerves.MixUtils

  test "prints OS command lines when NERVES_DEBUG=1" do
    EnvHelpers.put_env("NERVES_DEBUG", "1")

    output =
      capture_io(fn ->
        assert {"hello world", 0} = MixUtils.cmd("printf", ["%s", "hello world"])
      end)

    assert output == "$ printf %s 'hello world'\n"
  end

  test "does not print OS command lines by default" do
    EnvHelpers.delete_env("NERVES_DEBUG")

    output =
      capture_io(fn ->
        assert {"hello", 0} = MixUtils.cmd("printf", ["hello"])
      end)

    assert output == ""
  end

  test "prints shell command lines when NERVES_DEBUG=1" do
    EnvHelpers.put_env("NERVES_DEBUG", "1")

    output =
      capture_io(fn ->
        assert {"hello", 0} = MixUtils.shell_command("printf hello")
      end)

    assert output == "$ printf hello\n"
  end
end
