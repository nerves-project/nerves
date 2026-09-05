# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.ArtifactBuildTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Nerves.BuildPlan
  alias Nerves.BuildPlanHelpers
  alias Nerves.Container

  setup do
    BuildPlanHelpers.reset_plan()
  end

  # Spot check the task. See integration tests for better coverage.

  test "nerves.artifact.build raises when no Nerves packages are available" do
    Mix.Task.reenable("nerves.artifact.build")

    assert_raise Mix.Error, ~r/No Nerves packages found/, fn ->
      Mix.Task.run("nerves.artifact.build")
    end
  end

  test "nerves.artifact.build performs a full rebuild when requested" do
    archive_path = Path.join(System.tmp_dir!(), "nerves-artifact-build-test.tar.gz")
    File.write!(archive_path, "")
    on_exit(fn -> File.rm(archive_path) end)

    package = %{
      app: :test_system,
      download_path: Path.dirname(archive_path),
      downloads: [%{archive_path: archive_path}]
    }

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
                                     ["clean", "setup", "build"] ->
      ["run", "clean", "setup", "build"]
    end)
    |> expect(:work_dir, fn ^package -> "/work" end)

    InteractiveCmd
    |> expect(:cmd, fn "docker", ["run", "clean", "setup", "build"] -> {"", 0} end)

    Mix.Task.reenable("nerves.artifact.build")
    assert :ok = Mix.Task.run("nerves.artifact.build", ["--full"])
  end
end
