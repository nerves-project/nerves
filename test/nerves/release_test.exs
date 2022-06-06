defmodule Nerves.ReleaseTest do
  use NervesTest.Case, async: true

  @tag :release
  test "rootfs priorities from valid bootfile" do
    in_fixture("release_app", fn ->
      load_env()

      {_, 0} = System.cmd("mix", ["deps.get"], env: [{"MIX_ENV", "#{Mix.env()}"}])
      {_, 0} = System.cmd("mix", ["release"], env: [{"MIX_ENV", "#{Mix.env()}"}])

      generated =
        Path.join(Mix.Project.build_path(), "nerves/rootfs.priorities")
        |> File.read!()

      expected = File.read!("expected.rootfs.priorities")
      assert generated == expected
    end)
  end
end
