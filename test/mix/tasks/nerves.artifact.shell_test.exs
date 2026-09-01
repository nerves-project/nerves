# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.ArtifactShellTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Nerves.BuildPlan
  alias Nerves.BuildPlanHelpers
  alias Nerves.Container

  setup do
    BuildPlanHelpers.reset_plan()
  end

  # Spot check the task

  test "nerves.artifact.shell raises when no Nerves packages are available" do
    Mix.Task.reenable("nerves.artifact.shell")

    assert_raise Mix.Error, ~r/No Nerves packages found/, fn ->
      Mix.Task.run("nerves.artifact.shell")
    end
  end

  test "nerves.artifact.shell syncs source changes after the shell exits" do
    package = %{app: :test_system, path: "/tmp/test_system"}
    build_plan = %BuildPlan{packages: [package]}
    :persistent_term.put({Nerves, :build_plan}, {build_plan, false})
    test_pid = self()

    Container
    |> expect(:prepare_artifact_workspace!, fn ^build_plan, ^package ->
      {"docker", "image", "/downloads"}
    end)
    |> expect(:artifact_run_args, fn ^build_plan,
                                     ^package,
                                     "docker",
                                     "image",
                                     "/downloads",
                                     ["shell"] ->
      ["run", "shell"]
    end)
    |> expect(:work_dir, fn ^package -> "/work" end)
    |> expect(:sync_work_dir, fn "docker", ^package, "image" ->
      assert_received :shell_exited
      :ok
    end)

    InteractiveCmd
    |> expect(:cmd, fn "docker", ["run", "shell"] ->
      send(test_pid, :shell_exited)
      {"", 0}
    end)

    Mix.Task.reenable("nerves.artifact.shell")
    assert :ok = Mix.Task.run("nerves.artifact.shell")
  end
end
