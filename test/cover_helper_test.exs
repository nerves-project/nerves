# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule CoverHelperTest do
  use ExUnit.Case, async: true

  @helper_path Path.expand("fixtures/cover_helper/lib/cover_helper.ex", __DIR__)

  @tag :tmp_dir
  test "preloads coverage before Mix for host and target subprocesses", %{tmp_dir: tmp_dir} do
    # Exercise the launchers in an isolated VM without changing this VM's coverage.
    harness = """
    Code.require_file(#{inspect(@helper_path)})
    File.cd!(#{inspect(tmp_dir)})

    beam_path = Path.expand("_build/test/lib/nerves/ebin")
    File.mkdir_p!(beam_path)
    [{module, beam}] =
      Code.compile_string("defmodule CoverageProbe do\\n  def ping, do: :pong\\nend")
    beam_file = Path.join(beam_path, "Elixir.CoverageProbe.beam")
    File.write!(beam_file, beam)

    project_path = Path.expand("project with spaces")
    File.mkdir_p!(project_path)
    File.write!(Path.join(project_path, "mix.exs"), ~S'''
    ["help", "compile"] = System.argv()
    unless match?({:file, _}, :cover.is_compiled(CoverageProbe)) do
      raise "coverage must start before loading the project"
    end
    :pong = CoverageProbe.ping()
    defmodule Probe.MixProject do
      use Mix.Project
      def project, do: [app: :probe, version: "0.1.0"]
    end
    ''')

    {:ok, _} = :cover.start()
    {:ok, ^module} = :cover.compile_beam(String.to_charlist(beam_file))

    for target <- ["host", "rpi0"], interactive? <- [false, true] do
      opts = [
        cd: project_path,
        env: [{"MIX_ENV", "dev"}, {"MIX_TARGET", target}],
        into: ""
      ]
      args = ["help", "compile"]

      if interactive? do
        {:ok, output, 0} =
          CoverHelper.interactive_mix(args, [{:wait, ~r/mix compile/}], opts)
        true = output =~ "mix compile"
      else
        {output, 0} = CoverHelper.mix(args, opts)
        true = output =~ "mix compile"
      end
    end

    files = Path.wildcard("cover/*.coverdata")
    4 = length(files)
    :ok = :cover.reset(module)
    for file <- files, do: :ok = :cover.import(String.to_charlist(file))
    {:ok, calls} = :cover.analyse(module, :calls, :function)
    {{CoverageProbe, :ping, 0}, 4} =
      List.keyfind(calls, {CoverageProbe, :ping, 0}, 0)
    """

    {output, status} =
      System.cmd("elixir", ["-e", harness],
        stderr_to_stdout: true,
        env: [{"COVER_PATH", nil}, {"COVER_EXPORT", nil}]
      )

    assert status == 0, output
  end

  @tag :tmp_dir
  test "runs normally without coverage", %{tmp_dir: tmp_dir} do
    harness = """
    Code.require_file(#{inspect(@helper_path)})
    {output, 0} = CoverHelper.mix(["--version"], cd: #{inspect(tmp_dir)}, into: "")
    true = output =~ "Mix "
    {:ok, output, 0} =
      CoverHelper.interactive_mix(["--version"], [], cd: #{inspect(tmp_dir)})
    true = output =~ "Mix "
    """

    {output, status} =
      System.cmd("elixir", ["-e", harness],
        stderr_to_stdout: true,
        env: [{"COVER_PATH", nil}, {"COVER_EXPORT", nil}]
      )

    assert status == 0, output
    refute File.exists?(Path.join(tmp_dir, "cover"))
  end
end
