# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Integration.NervesSystemMinimalTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  @fixture_dir Path.expand("../fixtures/build_plans/nerves_system_minimal", __DIR__)

  @tag timeout: :timer.minutes(30)
  test "mix nerves.artifact.build creates an artifact tarball" do
    {_, 0} = CoverHelper.mix(["deps.get"], cd: @fixture_dir)

    dl_dir = Nerves.Paths.download_dir(:nerves_system_minimal, "0.4.1")

    # Clean everything up from previous runs first
    {_, 0} =
      CoverHelper.mix(["nerves.artifact.clean", "nerves_system_minimal", "--yes"],
        cd: @fixture_dir
      )

    assert !File.exists?(dl_dir) or File.ls!(dl_dir) == [],
           "Expecting download directory to be clean: #{dl_dir}"

    {_, exit_code} =
      CoverHelper.mix(["nerves.artifact.build"], cd: @fixture_dir)

    assert exit_code == 0, "mix nerves.artifact.build failed (exit #{exit_code})"

    assert File.dir?(dl_dir), "Expected download directory is missing: #{dl_dir}"

    tarball = Path.join(dl_dir, "nerves_system_minimal-portable-0.4.1-AC43A5A.tar.gz")
    assert File.regular?(tarball), "Expected archive is missing: #{tarball}"
  end
end
