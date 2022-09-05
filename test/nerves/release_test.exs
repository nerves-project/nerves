defmodule Nerves.ReleaseTest do
  use NervesTest.Case, async: true

  @tag :release
  test "rootfs priorities from valid bootfile" do
    in_fixture("release_app", fn ->
      load_env()

      {_, 0} = System.cmd("mix", ["deps.get"], env: [{"MIX_ENV", "#{Mix.env()}"}])
      {_, 0} = System.cmd("mix", ["release"], env: [{"MIX_ENV", "#{Mix.env()}"}])

      expected = """
      srv/erlang/releases/0.1.0/consolidated/Elixir.String.Chars.beam 32000
      srv/erlang/releases/0.1.0/consolidated/Elixir.List.Chars.beam 31999
      srv/erlang/releases/0.1.0/consolidated/Elixir.Inspect.beam 31998
      srv/erlang/releases/0.1.0/consolidated/Elixir.Enumerable.beam 31997
      srv/erlang/releases/0.1.0/consolidated/Elixir.Collectable.beam 31996
      """

      # TODO: Adjust this test to better check ordering
      # Asserting a specific generated priorities is brittle as it drastically
      # changes with each Elixir version. The ordering is also currently suboptimal.
      # For now, just check the file begins with the consolidated protocols
      # until the ordering is optimized and a better test can be constructed
      assert Path.join(Mix.Project.build_path(), "nerves/rootfs.priorities")
             |> File.read!()
             |> String.starts_with?(expected)
    end)
  end
end
