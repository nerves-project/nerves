# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Integration.NervesArtifactShellTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  @fixture_dir Path.expand("../fixtures/build_plans/nerves_system_minimal", __DIR__)
  @shell_prompt ~r|nerves@.*?/workspace/build.*?[$#] |

  @tag timeout: :timer.minutes(2)
  test "mix nerves.artifact.shell opens an interactive container shell" do
    {_, 0} = CoverHelper.mix(["deps.get"], cd: @fixture_dir, into: "")

    {_, 0} =
      CoverHelper.mix(["nerves.artifact.purge", "nerves_system_minimal", "--yes"],
        cd: @fixture_dir,
        into: ""
      )

    assert {:ok, output, 0} =
             CoverHelper.interactive_mix(
               ["nerves.artifact.shell"],
               [
                 {:wait, @shell_prompt},
                 {:write, "pwd\n"},
                 {:wait, ~r{/workspace/build}},
                 {:wait, @shell_prompt},
                 {:write, "exit\n"}
               ],
               cd: @fixture_dir,
               timeout: :timer.minutes(1)
             )

    # Spot check various messages that should have been printed along the way.
    assert output =~ "Preparing container workspace."
    assert output =~ "Buildroot extracted to /workspace"
    assert output =~ "IMPORTANT: If you update nerves_system_br, you should rerun this script."
    assert output =~ "Syncing source changes from container"
  end
end
