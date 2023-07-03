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

  @tag :tmp_dir
  @tag :release
  test "requires vm.args.eex", %{tmp_dir: tmp} do
    {path, env} = compile_fixture!("release_app", tmp, [], [])

    opts = [
      cd: path,
      env: [{"MIX_ENV", "prod"}, {"REL_TEMPLATES_PATH", Path.join(tmp, "no-rel")} | env],
      stderr_to_stdout: true
    ]

    assert {output, 1} = System.cmd("mix", ["release"], opts)

    assert output =~ ~r/Missing required .*vm\.args\.eex/
  end

  @tag :tmp_dir
  @tag :release
  test "fails if vm.args has incompatible shell setting", %{tmp_dir: tmp} do
    {path, env} = compile_fixture!("release_app", tmp, [], [])

    rel_templates_path = Path.join(tmp, "bad_rel")
    assert :ok = File.mkdir_p(rel_templates_path)
    bad_vm_args = Path.join(rel_templates_path, "vm.args.eex")

    expected =
      if Version.match?(System.version(), ">= 1.15.0") do
        assert :ok = File.write(bad_vm_args, "# test.vm.args\n-user Elixir.IEx.CLI")

        ~r"""
        Please remove the following lines:

        \* #{bad_vm_args}:2:
          -user Elixir.IEx.CLI

        Please ensure the following lines are in #{bad_vm_args}:
          -user elixir
          -run elixir start_iex
        """
      else
        assert :ok =
                 File.write(bad_vm_args, "# test.vm.args\n-user elixir\n-run elixir start_iex")

        ~r"""
        Please remove the following lines:

        \* #{bad_vm_args}:2:
          -user elixir
        \* #{bad_vm_args}:3:
          -run elixir start_iex

        Please ensure the following lines are in #{bad_vm_args}:
          -user Elixir.IEx.CLI
        """
      end

    opts = [
      cd: path,
      env: [{"MIX_ENV", "prod"}, {"REL_TEMPLATES_PATH", rel_templates_path} | env],
      stderr_to_stdout: true
    ]

    {output, 1} = System.cmd("mix", ["release"], opts)

    assert output =~ "Incompatible vm.args"
    assert output =~ expected
  end
end
