# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.BuildPlans.NervesV1SystemTest do
  use ExUnit.Case, async: false

  alias Nerves.BuildPlan
  alias Nerves.BuildPlanHelpers
  alias Nerves.Paths

  test "Nerves V1 system creates expected build plan" do
    app = :nerves_system_rpi0
    version = "2.1.1"

    package = BuildPlanHelpers.load_package(app)
    download_path = Paths.download_dir(app, version)
    artifact_path = Paths.artifact_dir(app, version)

    build_plan = Nerves.create_build_plan([package])
    package = BuildPlan.find_package(build_plan, app)
    assert package

    assert package.app == app
    assert package.version == version
    assert package.source_fingerprint == "7BE9066"
    assert package.download_path == download_path
    assert package.download_validators == [:archive]

    assert package.downloads == [
             %{
               version: version,
               filename: "nerves_system_rpi0-portable-2.1.1-7BE9066.tar.gz",
               archive_path:
                 Path.join(download_path, "nerves_system_rpi0-portable-2.1.1-7BE9066.tar.gz"),
               sites: [github_releases: "nerves-project/nerves_system_rpi0"]
             }
           ]

    assert build_plan.config[:bootfile] == "start.boot"
    assert build_plan.config[:rootfs_type] == :squashfs
    assert build_plan.config[:rootfs_inputs] == [Path.join(artifact_path, "images/rootfs.tar")]
    assert build_plan.config[:target_release_path] == "srv/erlang"
    assert build_plan.config[:fwup_conf] == Path.join(artifact_path, "images/fwup.conf")

    # Firmware metadata is pulled from this project, so skip check.

    assert build_plan.actions == [
             {Nerves.BuildAction.Erlinit,
              [
                base_erlinit_conf: Path.join(package.path, "rootfs_overlay/etc/erlinit.config"),
                shoehorn?: false
              ]},
             {Nerves.BuildAction.SortApps, []},
             {Nerves.BuildAction.AppModes, []},
             Nerves.BuildAction.Trimmer,
             Nerves.BuildAction.CheckExecutables,
             Nerves.BuildAction.StripAll,
             {Nerves.BuildAction.Rootfs, []},
             {Nerves.BuildAction.Firmware, []},
             {Nerves.BuildAction.NervesV1System,
              app: :nerves_system_rpi0,
              artifact_sites: [github_releases: "nerves-project/nerves_system_rpi0"],
              package_env: [
                {"TARGET_ARCH", "arm"},
                {"TARGET_CPU", "arm1176jzf_s"},
                {"TARGET_OS", "linux"},
                {"TARGET_ABI", "gnueabihf"},
                {"TARGET_GCC_FLAGS",
                 "-mabi=aapcs-linux -mfpu=vfp -marm -fstack-protector-strong -mfloat-abi=hard -mcpu=arm1176jzf-s -fPIE -pie -Wl,-z,now -Wl,-z,relro"}
              ]}
           ]

    # NOTE: rootfs_overlay paths added after untar
    assert build_plan.rootfs_overlays == []

    # NOTE: erts path discovered after untar
    assert build_plan.erts == true
  end

  @tag :tmp_dir
  test "NERVES_SYSTEM overrides download", %{tmp_dir: tmp_dir} do
    system_path = Path.join(tmp_dir, "nerves_system")
    File.mkdir_p!(Path.join(system_path, "images"))
    File.mkdir_p!(Path.join(system_path, "staging/usr/lib/erlang/erts-1"))
    File.mkdir_p!(Path.join(system_path, "staging/usr/lib/erlang/lib/erl_interface-1"))
    File.touch!(Path.join(system_path, "images/rootfs.tar"))
    BuildPlanHelpers.put_env("NERVES_SYSTEM", system_path)

    app = :nerves_system_rpi0
    version = "2.1.1"

    package = BuildPlanHelpers.load_package(app)
    download_path = Paths.download_dir(app, version)

    build_plan = Nerves.create_build_plan([package])
    package = BuildPlan.find_package(build_plan, app)
    assert package

    assert package.app == app
    assert package.version == version
    assert package.source_fingerprint == "7BE9066"
    assert package.download_path == download_path

    # These are some of the more important checks to make sure
    # there aren't any downloads and that the artifact is the provided
    # place.
    assert package.artifact_path == system_path
    assert package.download_validators == []
    assert package.downloads == []
    assert package.extractors == []

    assert build_plan.config[:bootfile] == "start.boot"
    assert build_plan.config[:rootfs_type] == :squashfs
    assert build_plan.config[:rootfs_inputs] == [Path.join(system_path, "images/rootfs.tar")]
    assert build_plan.config[:target_release_path] == "srv/erlang"
    assert build_plan.config[:fwup_conf] == Path.join(system_path, "images/fwup.conf")

    # Firmware metadata is pulled from this project, so skip check.

    assert build_plan.actions == [
             {Nerves.BuildAction.Erlinit,
              [
                base_erlinit_conf: Path.join(package.path, "rootfs_overlay/etc/erlinit.config"),
                shoehorn?: false
              ]},
             {Nerves.BuildAction.SortApps, []},
             {Nerves.BuildAction.AppModes, []},
             Nerves.BuildAction.Trimmer,
             Nerves.BuildAction.CheckExecutables,
             Nerves.BuildAction.StripAll,
             {Nerves.BuildAction.Rootfs, []},
             {Nerves.BuildAction.Firmware, []},
             {Nerves.BuildAction.NervesV1System,
              app: :nerves_system_rpi0,
              artifact_sites: [github_releases: "nerves-project/nerves_system_rpi0"],
              package_env: [
                {"TARGET_ARCH", "arm"},
                {"TARGET_CPU", "arm1176jzf_s"},
                {"TARGET_OS", "linux"},
                {"TARGET_ABI", "gnueabihf"},
                {"TARGET_GCC_FLAGS",
                 "-mabi=aapcs-linux -mfpu=vfp -marm -fstack-protector-strong -mfloat-abi=hard -mcpu=arm1176jzf-s -fPIE -pie -Wl,-z,now -Wl,-z,relro"}
              ]}
           ]

    # NOTE: rootfs_overlay paths added after untar
    assert build_plan.rootfs_overlays == []

    # NOTE: erts path discovered after untar
    assert build_plan.erts == true
  end
end
