defmodule Nerves.EnvTest do
  use NervesTest.Case

  test "Populate Nerves env" do
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
end
