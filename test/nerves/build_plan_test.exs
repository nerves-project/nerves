# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.BuildPlanTest do
  use ExUnit.Case, async: false

  alias Nerves.BuildPlan
  alias Nerves.BuildPlanHelpers
  alias Nerves.MixPackage

  test "Nerves v2 packages merge their configuration into the build plan" do
    package = %MixPackage{
      app: :system,
      config: [
        app: :system,
        version: "1.0.0",
        nerves: [config: [rootfs_type: :erofs, rootfs_flags: ["-T", "0"]]]
      ],
      dest: "system",
      deps: []
    }

    plan = Nerves.create_build_plan([package])

    assert plan.config[:rootfs_type] == :erofs
    assert plan.config[:rootfs_flags] == ["-T", "0"]
  end

  test "Nerves V1 actions derive toolchain and system variables from resolved artifacts" do
    BuildPlanHelpers.delete_env("TEST_NERVES_SYSTEM")
    BuildPlanHelpers.delete_env("TEST_NERVES_TOOLCHAIN")

    root = Path.join(System.tmp_dir!(), "nerves-build-plan-#{System.unique_integer([:positive])}")
    toolchain = Path.join(root, "toolchain")
    system = Path.join(root, "system")

    File.mkdir_p!(Path.join(toolchain, "bin"))
    File.touch!(Path.join(toolchain, "bin/arm-buildroot-linux-gnueabihf-gcc"))
    File.mkdir_p!(Path.join(system, "staging/usr/lib/erlang/erts-1/include"))
    File.mkdir_p!(Path.join(system, "staging/usr/lib/erlang/lib/erl_interface-1/include"))
    File.mkdir_p!(Path.join(system, "images"))
    File.mkdir_p!(Path.join(system, "rootfs_overlay/etc"))
    File.write!(Path.join(system, "rootfs_overlay/etc/erlinit.config"), "--boot start\n")

    :erl_tar.create(Path.join(system, "images/rootfs.tar"), [{~c"placeholder", <<1, 2, 3, 4>>}])

    on_exit(fn -> File.rm_rf!(root) end)

    plan =
      %BuildPlan{
        packages: [
          BuildPlanHelpers.package_info(:toolchain, toolchain, toolchain),
          BuildPlanHelpers.package_info(:system, system, system)
        ],
        config: %{host_tuple: Nerves.TargetTuple.new("x86_64-pc-linux-gnu")},
        env: %{"TARGET_GCC_FLAGS" => ""},
        actions: [
          {Nerves.BuildAction.NervesV1Toolchain,
           app: :toolchain, artifact_sites: [], package_env: [{"CC", "${CROSSCOMPILE}-gcc"}]},
          {Nerves.BuildAction.NervesV1System,
           app: :system,
           artifact_sites: [],
           package_env: [{"ERL_CFLAGS", "-I${ERTS_DIR}/include -I${ERL_INTERFACE_DIR}/include"}],
           dest: system,
           build_runner_opts: []}
        ]
      }
      |> BuildPlan.run_planning_actions(:pre_download)

    assert plan.config[:fwup_conf] == Path.join(system, "images/fwup.conf")

    assert plan.config[:fwup_provisioning_conf] ==
             Path.join(system, "images/fwup_include/provisioning.conf")

    assert plan.config[:rootfs_inputs] == [Path.join(system, "images/rootfs.tar")]

    plan = BuildPlan.run_planning_actions(plan, :post_extract)

    env = BuildPlan.fetch_interpolated_env!(plan)

    assert env["NERVES_TOOLCHAIN"] == toolchain
    assert env["CROSSCOMPILE"] == Path.join(toolchain, "bin/arm-buildroot-linux-gnueabihf")
    assert env["CC"] == "#{plan.env["CROSSCOMPILE"]}-gcc"
    assert env["NERVES_SYSTEM"] == system
    assert env["ERTS_DIR"] == Path.join(system, "staging/usr/lib/erlang/erts-1")

    assert env["ERL_CFLAGS"] ==
             "-I#{system}/staging/usr/lib/erlang/erts-1/include " <>
               "-I#{system}/staging/usr/lib/erlang/lib/erl_interface-1/include"
  end

  test "NERVES_SYSTEM and NERVES_TOOLCHAIN skip artifact downloads and extraction" do
    root = Path.join(System.tmp_dir!(), "nerves-build-plan-#{System.unique_integer([:positive])}")
    system = Path.join(root, "system")
    toolchain = Path.join(root, "toolchain")

    File.mkdir_p!(system)
    File.mkdir_p!(toolchain)
    restore_env = Map.take(System.get_env(), ["NERVES_SYSTEM", "NERVES_TOOLCHAIN"])

    System.put_env(%{"NERVES_SYSTEM" => system, "NERVES_TOOLCHAIN" => toolchain})

    on_exit(fn ->
      System.delete_env("NERVES_SYSTEM")
      System.delete_env("NERVES_TOOLCHAIN")
      System.put_env(restore_env)
      File.rm_rf!(root)
    end)

    build_plan =
      %BuildPlan{
        packages: [
          BuildPlanHelpers.package_info(:toolchain, "/deps/toolchain", "/artifacts/toolchain"),
          BuildPlanHelpers.package_info(:system, "/deps/system", "/artifacts/system")
        ],
        actions: [
          {Nerves.BuildAction.NervesV1Toolchain,
           app: :toolchain, artifact_sites: [], version: "1.0.0", build_runner_opts: []},
          {Nerves.BuildAction.NervesV1System,
           app: :system, artifact_sites: [], dest: system, version: "1.0.0", build_runner_opts: []}
        ]
      }
      |> BuildPlan.run_planning_actions(:pre_download)

    assert Enum.all?(build_plan.packages, fn package ->
             package.artifact_path in [system, toolchain] and
               package.download_validators == [] and
               package.downloads == [] and
               package.extractors == []
           end)
  end

  describe "fetch_interpolated_env!/1" do
    test "interpolates variables" do
      vars = %{"BASE" => "base", "DERIVED" => "derived->${BASE}"}
      build_plan = BuildPlan.merge_env(%BuildPlan{}, vars)

      # Variables are NOT interpolated on insertion
      assert build_plan.env == vars

      interpolated = BuildPlan.fetch_interpolated_env!(build_plan)
      assert interpolated == %{"BASE" => "base", "DERIVED" => "derived->base"}
    end

    test "raises on missing variables" do
      vars = %{"DERIVED" => "derived->${BASE}"}
      build_plan = BuildPlan.merge_env(%BuildPlan{}, vars)

      assert_raise KeyError, fn -> BuildPlan.fetch_interpolated_env!(build_plan) end
    end

    test "recursive interpolation of variables" do
      # Try to circumvent lucky map orderings
      vars = %{
        "A_VAR" => "${VAR3}",
        "Z_VAR" => "${VAR3}",
        "VAR1" => "var1",
        "VAR2" => "var2->${VAR1}",
        "VAR3" => "var3->${VAR2}"
      }

      build_plan = BuildPlan.merge_env(%BuildPlan{}, vars)

      interpolated = BuildPlan.fetch_interpolated_env!(build_plan)

      assert interpolated == %{
               "A_VAR" => "var3->var2->var1",
               "Z_VAR" => "var3->var2->var1",
               "VAR1" => "var1",
               "VAR2" => "var2->var1",
               "VAR3" => "var3->var2->var1"
             }
    end

    test "self-referential substitution raises" do
      vars = %{"VAR1" => "${VAR2}", "VAR2" => "${VAR1}"}
      build_plan = BuildPlan.merge_env(%BuildPlan{}, vars)

      assert_raise KeyError, fn -> BuildPlan.fetch_interpolated_env!(build_plan) end
    end
  end

  describe "fetch_interpolated_env!/2" do
    test "interpolates variables" do
      vars = %{"BASE" => "base", "DERIVED" => "derived->${BASE}"}
      build_plan = BuildPlan.merge_env(%BuildPlan{}, vars)

      assert "derived->base" == BuildPlan.fetch_interpolated_env!(build_plan, "DERIVED")
    end

    test "raises on missing variables" do
      vars = %{"DERIVED" => "derived->${BASE}"}
      build_plan = BuildPlan.merge_env(%BuildPlan{}, vars)

      assert_raise KeyError, fn -> BuildPlan.fetch_interpolated_env!(build_plan, "BASE") end
      assert_raise KeyError, fn -> BuildPlan.fetch_interpolated_env!(build_plan, "DERIVED") end
    end
  end

  describe "prepend_path/2" do
    test "prepends new paths" do
      env = %{"PATH" => "/a:/b:/c"}
      build_plan = %BuildPlan{env: env} |> BuildPlan.prepend_path("/d")
      assert build_plan.env == %{"PATH" => "/d:/a:/b:/c"}
    end

    test "ignores existing paths" do
      env = %{"PATH" => "/a:/b:/c"}
      build_plan = %BuildPlan{env: env} |> BuildPlan.prepend_path("/b")
      assert build_plan.env == %{"PATH" => "/a:/b:/c"}
    end

    test "prepending to empty path" do
      build_plan = %BuildPlan{} |> BuildPlan.prepend_path("/b")
      assert build_plan.env == %{"PATH" => "/b"}
    end

    test "path with spaces handling" do
      env = %{"PATH" => "/a:/b:/c"}

      build_plan =
        %BuildPlan{env: env} |> BuildPlan.prepend_path("/home/username/path with spaces/bin")

      # This is a trick question that's mostly a reminder to me that quotes aren't used since
      # the OS splits on the color.
      assert build_plan.env == %{"PATH" => "/home/username/path with spaces/bin:/a:/b:/c"}
    end
  end
end
