# SPDX-FileCopyrightText: 2019 Justin Schneck
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.MixTest do
  use NervesTest.Case, async: false

  describe "mix burn" do
    test "raise when passing firmware file that does not exist", context do
      in_tmp(context.test, fn ->
        assert_raise Mix.Error, fn ->
          Mix.Tasks.Burn.firmware_file(firmware: "/tmp/does_not_exist")
        end
      end)
    end

    test "can pass firmware file path", context do
      in_tmp(context.test, fn ->
        fw = "tmp.fw"
        File.touch(fw)
        assert Path.expand(fw) == Mix.Tasks.Burn.firmware_file(firmware: fw)
      end)
    end
  end
end
