# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.ArtifactCleanTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Nerves.BuildPlan
  alias Nerves.BuildPlanHelpers
  alias Nerves.Container

  setup do
    BuildPlanHelpers.reset_plan()
  end

  test "nerves.artifact.clean cleans the container build directory" do
    package = %{app: :test_system}
    build_plan = %BuildPlan{packages: [package]}
    :persistent_term.put({Nerves, :build_plan}, {build_plan, false})

    Container
    |> expect(:prepare_artifact_workspace!, fn ^build_plan, ^package ->
      {"docker", "image", "/downloads", true}
    end)
    |> expect(:artifact_run_args, fn ^build_plan,
                                     ^package,
                                     "docker",
                                     "image",
                                     "/downloads",
                                     ["clean"] ->
      ["run", "clean"]
    end)
    |> expect(:invalidate_source_checksum, fn ^package -> :ok end)

    InteractiveCmd
    |> expect(:cmd, fn "docker", ["run", "clean"] -> {"", 0} end)

    Mix.Task.reenable("nerves.artifact.clean")
    assert :ok = Mix.Task.run("nerves.artifact.clean")
  end
end
