defmodule Nerves.EnvTest do
  use NervesTest.Case, async: false
  alias Nerves.Env

  test "populate Nerves env" do
    in_fixture "simple_app", fn ->
      packages =
        ~w(system toolchain system_platform toolchain_platform)
        |> Enum.sort

      env_pkgs =
        packages
        |> load_env
        |> Enum.map(& &1.app)
        |> Enum.map(&Atom.to_string/1)
        |> Enum.sort

      assert packages == env_pkgs
    end
  end

  test "determine host arch" do
    assert Env.parse_arch("win32") == "x86_64"
    assert Env.parse_arch("x86_64-apple-darwin14.1.0") == "x86_64"
    assert Env.parse_arch("armv7l-unknown-linux-gnueabihf") == "arm"
    assert Env.parse_arch("unknown") == "x86_64"
  end

  test "determine host platform" do
    assert Env.parse_platform("win32") == "win"
    assert Env.parse_platform("x86_64-apple-darwin14.1.0") == "darwin"
    assert Env.parse_platform("x86_64-unknown-linux-gnu") == "linux"
    assert_raise Mix.Error, fn ->
      Env.parse_platform("unknown")
    end
  end
end
