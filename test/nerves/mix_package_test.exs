# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.MixPackageTest do
  use ExUnit.Case, async: true

  alias Nerves.MixPackage

  test "transitive closure handles app: false dependencies missing from the graph" do
    # Mix omits the entry for an app: false dependency, but still references it.
    app_tree = %{
      my_app: [:my_library],
      my_library: [:headers, :runtime_library],
      runtime_library: []
    }

    closure =
      app_tree
      |> MixPackage.transitive_closure()
      |> Map.new(fn {app, deps} -> {app, Enum.sort(deps)} end)

    assert closure == %{
             my_app: [:headers, :my_library, :runtime_library],
             my_library: [:headers, :runtime_library],
             runtime_library: []
           }
  end
end
