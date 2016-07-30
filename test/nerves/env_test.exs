defmodule Nerves.EnvTest do
  use NervesTest.Case

  test "Populate Nerves env" do
    in_fixture "simple_app", fn ->
      packages = ~w(system toolchain system_platform toolchain_platform)
      |> Enum.sort

      Enum.each(packages, fn (package) ->
        path = Path.expand("#{File.cwd!}/../#{package}")
        fixture_to_tmp(package, path)
      end)

      File.cwd!
      |> Path.join("mix.exs")
      |> Code.require_file()

      Nerves.Env.start
      env_pkgs = Nerves.Env.packages
      |> Enum.map(& &1.app)
      |> Enum.map(&Atom.to_string/1)
      |> Enum.sort

      assert packages == env_pkgs
    end
  end
end
