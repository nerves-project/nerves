defmodule Nerves.MixTest do
  use NervesTest.Case, async: false

  describe "mix burn" do
    test "raise when passing firmware file that does not exist" do
      in_fixture("simple_app", fn ->
        System.put_env("MIX_TARGET", "target")

        ~w(system toolchain system_platform toolchain_platform)
        |> load_env()

        assert_raise Mix.Error, fn ->
          Mix.Tasks.Burn.run(["--firmware", "/tmp/does_not_exist"])
        end

        System.delete_env("MIX_TARGET")
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
