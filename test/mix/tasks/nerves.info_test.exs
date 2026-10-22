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

  test "a malformed report.json prints report unreadable instead of crashing" do
    path = Path.join([Mix.Project.build_path(), "lib", ".precompiled"])
    File.mkdir_p!(path)
    File.write!(Path.join(path, "report.json"), "{not valid json")
    on_exit(fn -> File.rm_rf!(path) end)

    output =
      ExUnit.CaptureIO.capture_io(fn ->
        Mix.Task.rerun("nerves.info")
      end)

    assert output =~ "Precompiled:      report unreadable"
  end

  test "a report.json missing optional keys defaults them to zero/empty" do
    path = Path.join([Mix.Project.build_path(), "lib", ".precompiled"])
    File.mkdir_p!(path)
    File.write!(Path.join(path, "report.json"), :json.encode(%{"hits" => 1}))
    on_exit(fn -> File.rm_rf!(path) end)

    output =
      ExUnit.CaptureIO.capture_io(fn ->
        Mix.Task.rerun("nerves.info")
      end)

    assert output =~ "Precompiled:      1 hit, 0 miss, 0 fail"
    refute output =~ "HIT"
    refute output =~ "MISS"
    refute output =~ "FAIL"
  end

  for {label, report} <- [
        {"a non-integer counter", %{"hits" => "1"}},
        {"lines that are not a list", %{"hits" => 1, "lines" => "x"}},
        {"a non-string status",
         %{"lines" => [%{"name" => "a", "version" => "1", "status" => 1, "detail" => "d"}]}},
        {"a non-map line", %{"lines" => [1]}}
      ] do
    test "a report.json with #{label} prints report unreadable" do
      path = Path.join([Mix.Project.build_path(), "lib", ".precompiled"])
      File.mkdir_p!(path)
      File.write!(Path.join(path, "report.json"), :json.encode(unquote(Macro.escape(report))))
      on_exit(fn -> File.rm_rf!(path) end)

      output = ExUnit.CaptureIO.capture_io(fn -> Mix.Task.rerun("nerves.info") end)
      assert output =~ "Precompiled:      report unreadable"
    end
  end
end
