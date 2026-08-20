# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.PathsTest do
  use ExUnit.Case, async: false

  alias Nerves.BuildPlanHelpers
  alias Nerves.Paths

  test "uses default data and download directory paths" do
    BuildPlanHelpers.delete_env("NERVES_DATA_DIR")
    BuildPlanHelpers.delete_env("NERVES_DL_DIR")

    assert Paths.data_dir() == Path.join(System.user_home!(), ".nerves")
    assert Paths.download_dir() == Path.expand(Path.join(Paths.data_dir(), "dl"))
    assert Paths.artifact_dir() == Path.join(Paths.data_dir(), "artifacts") |> Path.expand()
  end

  test "respects environment overrides for directories" do
    BuildPlanHelpers.put_env("NERVES_DATA_DIR", "/tmp/nerves-data")
    BuildPlanHelpers.put_env("NERVES_DL_DIR", "/tmp/nerves-dl")

    assert Paths.data_dir() == "/tmp/nerves-data"
    assert Paths.download_dir() == "/tmp/nerves-dl"
    assert Paths.artifact_dir() == Path.join("/tmp/nerves-data", "artifacts") |> Path.expand()
  end

  test "builds app-specific download and artifact paths" do
    version = Version.parse!("1.2.3")

    assert Paths.download_dir(:nerves_system_rpi0, version) ==
             Path.join(Paths.download_dir(), "nerves_system_rpi0-1.2.3")

    assert Paths.artifact_dir(:nerves_system_rpi0, version) ==
             Path.join(Paths.artifact_dir(), "nerves_system_rpi0-1.2.3")
  end

  @tag :tmp_dir
  test "finds executable files and skips noscrub directories", %{tmp_dir: root} do
    File.mkdir_p!(Path.join(root, "bin"))
    File.mkdir_p!(Path.join(root, "nested"))
    File.mkdir_p!(Path.join(root, "skip"))

    tool = Path.join([root, "bin", "tool"])
    nested = Path.join([root, "nested", "script"])
    skipped = Path.join([root, "skip", "ignored"])

    File.write!(tool, "tool")
    File.write!(nested, "script")
    File.write!(skipped, "hidden")
    File.write!(Path.join([root, "skip", ".noscrub"]), "")

    File.chmod!(tool, 0o755)
    File.chmod!(nested, 0o755)
    File.chmod!(skipped, 0o755)

    assert Enum.sort(Paths.executable_paths(root)) == Enum.sort([tool, nested])
  end

  @tag :tmp_dir
  test "dir_size reports total directory usage", %{tmp_dir: root} do
    File.write!(Path.join(root, "test.bin"), :binary.copy(<<0>>, 1024))

    result = Paths.dir_size(root)

    # On disk size can vary depending on the filesystem, so don't try to
    # match too tightly. It's probably 4K.
    assert result > 0
    assert result <= 128 * 1024
  end
end
