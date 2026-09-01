# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.BuildPlans.NervesV1ToolchainTest do
  use ExUnit.Case, async: false

  alias Nerves.BuildPlan
  alias Nerves.BuildPlanHelpers
  alias Nerves.Paths

  test "Nerves V1 toolchain creates expected build plan" do
    app = :nerves_toolchain_aarch64_nerves_linux_gnu
    package = BuildPlanHelpers.load_package(app)
    download_path = Paths.download_dir(app, "15.3.0")
    archive_name = "#{app}-linux_x86_64-15.3.0-3006C1F.tar.xz"

    build_plan =
      Nerves.create_build_plan([package],
        host_tuple: Nerves.TargetTuple.new("x86_64-pc-linux-gnu")
      )

    package = BuildPlan.find_package(build_plan, app)
    assert package

    assert package.app == app
    assert package.version == "15.3.0"
    assert package.source_fingerprint == "3006C1F"
    assert package.download_path == download_path
    assert package.download_validators == [:archive]

    assert package.downloads == [
             %{
               version: "15.3.0",
               filename: archive_name,
               archive_path: Path.join(download_path, archive_name),
               sites: [github_releases: "nerves-project/toolchains"]
             }
           ]

    assert build_plan.config[:bootfile] == "start.boot"

    assert build_plan.config[:rootfs_type] == :squashfs

    assert build_plan.config[:target_release_path] == "srv/erlang"
    # Firmware metadata is pulled from this project, so skip check.

    assert build_plan.actions == [
             {Nerves.BuildAction.NervesV1Toolchain,
              app: app,
              artifact_sites: [github_releases: "nerves-project/toolchains"],
              package_env: [],
              build_runner_opts: []}
           ]
  end
end
