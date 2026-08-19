# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.InfoTest do
  use ExUnit.Case, async: true

  test "prints versioned Nerves information" do
    output =
      ExUnit.CaptureIO.capture_io(fn ->
        Mix.Task.run("nerves.info")
      end)

    component_versions =
      for line <- String.split(output, "\n", trim: true) do
        [component, version] = String.split(line, ":")
        {String.trim(component), Version.parse!(String.trim(version))}
      end

    assert length(component_versions) == 3

    components = Enum.map(component_versions, &elem(&1, 0))
    assert components == ["Nerves", "Nerves Bootstrap", "Elixir"]
  end
end
