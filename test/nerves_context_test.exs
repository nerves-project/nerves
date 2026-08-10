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

    assert plan.env["NERVES_TOOLCHAIN"] == toolchain
    assert plan.env["CROSSCOMPILE"] == Path.join(toolchain, "bin/arm-buildroot-linux-gnueabihf")
    assert plan.env["CC"] == "#{plan.env["CROSSCOMPILE"]}-gcc"
    assert plan.env["NERVES_SYSTEM"] == system
    assert plan.env["ERTS_DIR"] == Path.join(system, "staging/usr/lib/erlang/erts-1")

    assert plan.env["ERL_CFLAGS"] ==
             "-I#{system}/staging/usr/lib/erlang/erts-1/include " <>
               "-I#{system}/staging/usr/lib/erlang/lib/erl_interface-1/include"
  end
end
