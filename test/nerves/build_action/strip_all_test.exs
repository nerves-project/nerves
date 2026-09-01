# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.BuildAction.StripAllTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Nerves.BuildAction.StripAll
  alias Nerves.BuildPlan

  @tag :tmp_dir
  test "post_assemble_steps succeeds when strip command passes", %{tmp_dir: tmp_dir} do
    log = Path.join(tmp_dir, "strip.log")
    strip = make_strip_command(tmp_dir, log)
    good_elves = for i <- 1..20, do: "#{i}.elf"
    release = make_release(tmp_dir, good_elves, ["script", "data.txt"])
    build_plan = %BuildPlan{env: %{"STRIP" => strip}}

    assert StripAll.post_assemble_steps(build_plan, release, []) == release

    good_elf_paths = Enum.map(good_elves, &Path.join(release.path, &1)) |> Enum.sort()
    assert read_strip_log(log) == good_elf_paths
  end

  @tag :tmp_dir
  test "post_assemble_steps outputs warning when strip command fails", %{tmp_dir: tmp_dir} do
    log = Path.join(tmp_dir, "strip.log")
    strip = make_strip_command(tmp_dir, log, "bad.elf")
    release = make_release(tmp_dir, ["good.elf", "bad.elf"], ["script", "data.txt"])
    build_plan = %BuildPlan{env: %{"STRIP" => strip}}

    output =
      capture_io(fn ->
        assert StripAll.post_assemble_steps(build_plan, release, []) == release
      end)

    assert output =~ "WARNING: Can't remove debug symbols"
    assert output =~ "bad.elf"

    assert read_strip_log(log) == [
             Path.join(release.path, "bad.elf"),
             Path.join(release.path, "good.elf")
           ]
  end

  @tag :tmp_dir
  test "post_assemble_steps raises when passed a bad path", %{tmp_dir: tmp_dir} do
    strip = make_strip_command(tmp_dir, Path.join(tmp_dir, "strip.log"))
    release = %Mix.Release{name: :test, version: "0.1.0", path: Path.join(tmp_dir, "missing")}
    build_plan = %BuildPlan{env: %{"STRIP" => strip}}

    assert_raise File.Error, fn ->
      StripAll.post_assemble_steps(build_plan, release, [])
    end
  end

  defp make_release(tmp_dir, elf_files, other_files) do
    release_path = Path.join(tmp_dir, "release")
    File.mkdir_p!(release_path)

    Enum.each(elf_files, &write_executable(release_path, &1, elf_header()))
    Enum.each(other_files, &write_executable(release_path, &1, "not an ELF file"))

    %Mix.Release{name: :test, version: "0.1.0", path: release_path}
  end

  defp make_strip_command(tmp_dir, log, fail_name \\ "") do
    strip = Path.join(tmp_dir, "strip")

    File.write!(strip, """
    #!/bin/sh
    printf '%s\n' "$1" >> "#{log}"
    test "$(basename "$1")" != "#{fail_name}"
    """)

    File.chmod!(strip, 0o755)
    strip
  end

  defp write_executable(directory, name, contents) do
    path = Path.join(directory, name)
    File.write!(path, contents)
    File.chmod!(path, 0o755)
  end

  defp read_strip_log(log) do
    log
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.sort()
  end

  defp elf_header() do
    <<0x7F, "ELF", 1, 1, 1, 0, 0, 0::size(56), 0::size((52 - 16) * 8)>>
  end
end
