# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.BuildPlanTest do
  use ExUnit.Case, async: true

  alias Nerves.BuildPlan
  alias Nerves.MixPackage

  test "converts legacy metadata to global environment and artifact hooks" do
    base_package = %{
      artifact_path: "/artifacts/system",
      deps: [],
      download_path: "/downloads/system",
      download_validators: [],
      downloads: [],
      extractors: [],
      source_fingerprint: "ABC123",
      source_fingerprint_files: ["mix.exs"],
      validated_files: []
    }

    package = %MixPackage{
      app: :system,
      config: %{
        version: "1.0.0",
        nerves_package: [type: :system, artifact_sites: ["https://example.com"]]
      }
    }

    config =
      Nerves.LegacyPackage.convert(package, base_package)

    assert config[:env] == %{"NERVES_SYSTEM" => "/artifacts/system"}

    assert hd(config[:packages]).downloads == [
             %{
               archive_path: "/downloads/system/system-portable-1.0.0-ABC123.tar.gz",
               filename: "system-portable-1.0.0-ABC123.tar.gz",
               sites: ["https://example.com"],
               version: "1.0.0"
             }
           ]
  end

  test "legacy callbacks derive toolchain and system variables from resolved artifacts" do
    root = Path.join(System.tmp_dir!(), "nerves-build-plan-#{System.unique_integer([:positive])}")
    toolchain = Path.join(root, "toolchain")
    system = Path.join(root, "system")

    File.mkdir_p!(Path.join(toolchain, "bin"))
    File.touch!(Path.join(toolchain, "bin/arm-buildroot-linux-gnueabihf-gcc"))
    File.mkdir_p!(Path.join(system, "staging/usr/lib/erlang/erts-1/include"))
    File.mkdir_p!(Path.join(system, "staging/usr/lib/erlang/lib/erl_interface-1/include"))
    File.mkdir_p!(Path.join(system, "images"))

    :erl_tar.create(Path.join(system, "images/rootfs.tar"), [{~c"placeholder", <<1, 2, 3, 4>>}])

    on_exit(fn -> File.rm_rf!(root) end)

    plan =
      %BuildPlan{}
      |> BuildPlan.merge_env(%{"NERVES_TOOLCHAIN" => toolchain, "NERVES_SYSTEM" => system})
      |> Nerves.LegacyPackage.apply_legacy_package(
        type: :toolchain,
        artifact_path: toolchain,
        package_env: [{"CC", "${CROSSCOMPILE}-gcc"}],
        dest: toolchain
      )
      |> Nerves.LegacyPackage.apply_legacy_package(
        type: :system,
        artifact_path: system,
        package_env: [{"ERL_CFLAGS", "-I${ERTS_DIR}/include -I${ERL_INTERFACE_DIR}/include"}],
        dest: system
      )

    env = BuildPlan.get_interpolated_env(plan)

    assert env["NERVES_TOOLCHAIN"] == toolchain
    assert env["CROSSCOMPILE"] == Path.join(toolchain, "bin/arm-buildroot-linux-gnueabihf")
    assert env["CC"] == "#{plan.env["CROSSCOMPILE"]}-gcc"
    assert env["NERVES_SYSTEM"] == system
    assert env["ERTS_DIR"] == Path.join(system, "staging/usr/lib/erlang/erts-1")

    assert env["ERL_CFLAGS"] ==
             "-I#{system}/staging/usr/lib/erlang/erts-1/include " <>
               "-I#{system}/staging/usr/lib/erlang/lib/erl_interface-1/include"
  end

  describe "get_interpolated_env/1" do
    test "interpolates variables" do
      vars = %{"BASE" => "base", "DERIVED" => "derived->${BASE}"}
      build_plan = BuildPlan.merge_env(%BuildPlan{}, vars)

      # Variables are NOT interpolated on insertion
      assert build_plan.env == vars

      interpolated = BuildPlan.get_interpolated_env(build_plan)
      assert interpolated == %{"BASE" => "base", "DERIVED" => "derived->base"}
    end

    test "raises on missing variables" do
      vars = %{"DERIVED" => "derived->${BASE}"}
      build_plan = BuildPlan.merge_env(%BuildPlan{}, vars)

      assert_raise KeyError, fn -> BuildPlan.get_interpolated_env(build_plan) end
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

      interpolated = BuildPlan.get_interpolated_env(build_plan)

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

      assert_raise KeyError, fn -> BuildPlan.get_interpolated_env(build_plan) end
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
