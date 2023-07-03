defmodule Nerves.ReleaseTest do
  use NervesTest.Case, async: true

  @tag :tmp_dir
  @tag :release
  test "rootfs priorities from valid bootfile", %{tmp_dir: tmp} do
    {path, env} = compile_fixture!("release_app", tmp, [], [])

    opts = [cd: path, env: [{"MIX_ENV", "prod"} | env], stderr_to_stdout: true]
    {output, exit_status} = System.cmd("mix", ["release"], opts)

    assert exit_status == 0, output

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
    assert Path.join(path, "_build/prod/nerves/rootfs.priorities")
           |> File.read!()
           |> String.starts_with?(expected)
  end
end
