# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.InfoTest do
  use ExUnit.Case, async: false

  test "prints versioned Nerves information" do
    output =
      ExUnit.CaptureIO.capture_io(fn ->
        Mix.Task.rerun("nerves.info")
      end)

    [nerves_line, bootstrap_line, elixir_line, precompiled_line] =
      String.split(output, "\n", trim: true)

    component_versions =
      for line <- [nerves_line, bootstrap_line, elixir_line] do
        [component, version] = String.split(line, ":")
        {String.trim(component), Version.parse!(String.trim(version))}
      end

    components = Enum.map(component_versions, &elem(&1, 0))
    assert components == ["Nerves", "Nerves Bootstrap", "Elixir"]

    assert String.starts_with?(precompiled_line, "Precompiled:")
  end

  test "reports the last precompiled run from report.json" do
    path = Path.join([Mix.Project.build_path(), "lib", ".precompiled"])
    File.mkdir_p!(path)

    report = %{
      "hits" => 1,
      "misses" => 1,
      "fails" => 0,
      "bytes" => 0,
      "seconds" => 0.0,
      "lines" => [
        %{"name" => "ash", "version" => "3.5.2", "status" => "hit", "detail" => "0.0 MB"},
        %{"name" => "jason", "version" => "1.4.5", "status" => "miss", "detail" => "not in batch"}
      ]
    }

    File.write!(Path.join(path, "report.json"), :json.encode(report))
    on_exit(fn -> File.rm_rf!(path) end)

    output =
      ExUnit.CaptureIO.capture_io(fn ->
        Mix.Task.rerun("nerves.info")
      end)

    assert output =~ "Precompiled:      1 hit, 1 miss, 0 fail"
    assert output =~ "jason 1.4.5  MISS  not in batch"
    refute output =~ "ash 3.5.2  HIT"
  end
end
