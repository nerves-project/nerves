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

  test "--image removes only the selected image after cleaning" do
    prepare_clean(0)

    expect(Nerves.MixUtils, :cmd, fn "docker", ["image", "rm", "image"], opts ->
      assert opts == [stderr_to_stdout: true]
      {"", 0}
    end)

    assert :ok = Mix.Task.run("nerves.artifact.clean", ["--image", "test_system"])
  end

  test "--image reports removal failures" do
    prepare_clean(0)

    expect(Nerves.MixUtils, :cmd, fn "docker", ["image", "rm", "image"], _ ->
      {"image is in use", 1}
    end)

    assert_raise Mix.Error, ~r/Container image removal failed.*image is in use/, fn ->
      Mix.Task.run("nerves.artifact.clean", ["--image"])
    end
  end

  test "--image does not remove the image when cleaning fails" do
    prepare_clean(2)
    reject(Nerves.MixUtils, :cmd, 3)

    assert_raise Mix.Error, "Container clean failed with status 2", fn ->
      Mix.Task.run("nerves.artifact.clean", ["--image"])
    end
  end

  defp prepare_clean(status) do
    package = %{app: :test_system}
    plan = %BuildPlan{packages: [package]}
    :persistent_term.put({Nerves, :build_plan}, {plan, false})
    Mix.Task.reenable("nerves.artifact.clean")

    expect(Container, :prepare_artifact_workspace!, fn ^plan, ^package ->
      {"docker", "image", "/downloads", true}
    end)

    expect(Container, :artifact_run_args, fn ^plan,
                                             ^package,
                                             "docker",
                                             "image",
                                             "/downloads",
                                             ["clean"] ->
      ["run", "clean"]
    end)

    expect(InteractiveCmd, :cmd, fn "docker", ["run", "clean"] -> {"", status} end)

    if status == 0 do
      expect(Container, :invalidate_source_checksum, fn ^package -> :ok end)
    end
  end
end
