# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.ContainerTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Nerves.BuildPlan
  alias Nerves.Container

  @moduletag :tmp_dir

  test "artifact arguments follow their respective commands", %{tmp_dir: tmp_dir} do
    build_plan = %BuildPlan{config: %{host_tuple: Nerves.TargetTuple.new()}}
    package = Nerves.BuildPlanHelpers.package_info(:test_package, tmp_dir, tmp_dir)

    build_args = [
      "BR2_PRIMARY_SITE=https://example.com/source files",
      "VALUE='quoted' \"$HOME\" *.c",
      "source",
      "all",
      "legal-info"
    ]

    package = %{
      package
      | artifact_command_args: %{
          "build" => build_args,
          "clean" => ["--all"],
          "shell" => ["--norc"]
        }
    }

    for {commands, expected} <- [
          {["build"], ["build" | build_args]},
          {["setup", "build"], ["setup", "build" | build_args]},
          {["clean", "setup", "build"], ["clean", "--all", "setup", "build" | build_args]},
          {["shell"], ["shell", "--norc"]},
          {[], []}
        ] do
      args =
        Container.artifact_run_args(
          build_plan,
          package,
          "docker",
          "image",
          "/downloads",
          commands
        )

      assert Enum.drop_while(args, &(&1 != "image")) == ["image" | expected]
    end

    package = %{package | artifact_command_args: %{}}

    args =
      Container.artifact_run_args(build_plan, package, "docker", "image", "/downloads", ["build"])

    assert Enum.take(args, -2) == ["image", "build"]
  end

  test "legacy artifact entrypoint passes make arguments before packaging", %{tmp_dir: tmp_dir} do
    build_dir = Path.join(tmp_dir, "build")
    bin_dir = Path.join(tmp_dir, "bin")
    artifact_dir = Path.join(tmp_dir, "artifacts")
    log = Path.join(tmp_dir, "make.log")
    File.mkdir_p!(build_dir)
    File.mkdir_p!(bin_dir)

    script = Path.join(tmp_dir, "nerves-artifact")

    File.write!(
      script,
      :nerves
      |> :code.priv_dir()
      |> Path.join("artifact/nerves-artifact")
      |> File.read!()
      |> String.replace("/workspace", tmp_dir)
    )

    make = Path.join(bin_dir, "make")

    File.write!(make, """
    #!/bin/sh
    printf 'make\\n' >> "$MAKE_LOG"
    for arg in "$@"; do
      printf '<%s>\\n' "$arg" >> "$MAKE_LOG"
    done
    touch result.tar.gz
    """)

    File.chmod!(make, 0o755)

    make_args = [
      "SITE=source files",
      "VALUE='quoted' \"$HOME\" *.c",
      "source",
      "all",
      "legal-info"
    ]

    env = [
      {"PATH", bin_dir <> ":" <> System.fetch_env!("PATH")},
      {"MAKE_LOG", log},
      {"NERVES_ARTIFACT_APP", "test_system"},
      {"NERVES_ARTIFACT_VERSION", "1.0.0"},
      {"NERVES_ARTIFACT_SOURCE_FINGERPRINT", "ABC123"},
      {"NERVES_ARTIFACT_DIR", artifact_dir}
    ]

    for args <- [make_args, []] do
      File.write!(log, "")
      assert {_, 0} = System.cmd("sh", [script, "build" | args], env: env, stderr_to_stdout: true)

      expected =
        "make\n" <>
          Enum.map_join(args, "", &"<#{&1}>\n") <>
          "make\n<system>\n<NERVES_ARTIFACT_NAME=test_system-portable-1.0.0-ABC123>\n"

      assert File.read!(log) == expected
      assert File.regular?(Path.join(artifact_dir, "result.tar.gz"))
    end
  end

  test "workspace checksum does not depend on the artifact fingerprint", %{tmp_dir: tmp_dir} do
    dockerfile = Path.join(tmp_dir, "Dockerfile")
    source = Path.join(tmp_dir, "source")
    input = Path.join(source, "input")
    File.write!(dockerfile, "FROM scratch\n")
    File.mkdir!(source)
    File.write!(input, "contents")

    package = %{
      app: :test_package,
      deps: [],
      dockerfile: dockerfile,
      path: source,
      source_fingerprint: "OLD",
      artifact_source_files: [input]
    }

    build_plan = %BuildPlan{packages: [package]}
    checksum = Container.workspace_checksum(build_plan, package)
    changed_fingerprint = %{package | source_fingerprint: "NEW"}

    assert Container.workspace_checksum(build_plan, changed_fingerprint) == checksum
  end

  if :os.type() == {:unix, :linux} do
    test "Linux copies source directly into the workspace", %{tmp_dir: tmp_dir} do
      source = Path.join(tmp_dir, "source")
      File.mkdir!(source)
      File.write!(Path.join(source, "input"), "contents")

      package = %{app: :test_package, deps: [], path: source}
      build_plan = %BuildPlan{packages: [package]}
      on_exit(fn -> File.rm_rf(Container.work_dir(package)) end)

      assert :ok = Container.populate_work_dir(build_plan, "docker", package, "image")

      copied_input = Path.join([Container.work_dir(package), "test_package", "input"])
      assert File.read!(copied_input) == "contents"
    end

    test "Linux sync uses package-relative paths", %{tmp_dir: tmp_dir} do
      source = Path.join(tmp_dir, "source")
      input = Path.join([source, "nested", "input"])
      dockerfile = Path.join(tmp_dir, "Dockerfile")
      File.mkdir_p!(Path.dirname(input))
      File.write!(input, "old contents")
      File.write!(dockerfile, "FROM scratch\n")

      package = %{
        app: :test_package,
        deps: [],
        dockerfile: dockerfile,
        path: source,
        artifact_source_files: [input]
      }

      build_plan = %BuildPlan{packages: [package]}
      on_exit(fn -> File.rm_rf(Container.work_dir(package)) end)

      assert :ok = Container.populate_work_dir(build_plan, "docker", package, "image")

      copied_input = Path.join([Container.work_dir(package), "test_package", "nested", "input"])
      File.write!(copied_input, "new contents")

      assert :ok = Container.sync_work_dir(build_plan, "docker", package, "image")
      assert File.read!(input) == "new contents"
    end
  else
    test "Docker copies source through a running container into the workspace volume", %{
      tmp_dir: tmp_dir
    } do
      source = Path.join(tmp_dir, "source")
      File.mkdir!(source)
      File.write!(Path.join(source, "input"), "contents")

      package = %{app: :test_package, deps: [], path: source}
      build_plan = %BuildPlan{packages: [package]}
      test_pid = self()

      stub(Nerves.MixUtils, :cmd, fn executable, args, options ->
        send(test_pid, {:cmd, executable, args, options})
        {"", 0}
      end)

      assert :ok = Container.populate_work_dir(build_plan, "docker", package, "image")

      assert_received {:cmd, "docker",
                       [
                         "run",
                         "--rm",
                         "--user",
                         "root",
                         "--mount",
                         "type=volume,src=nerves-work-test_package,target=/workspace",
                         "--mount",
                         "type=bind,src=" <> _,
                         "--entrypoint",
                         "/bin/sh",
                         "image",
                         "-c",
                         "cp -a /source/. /workspace/test_package && chown -R \"$(stat -c %u:%g /workspace)\" /workspace/test_package"
                       ], stderr_to_stdout: true}

      refute_received {:cmd, "docker", ["create" | _], _}
      refute_received {:cmd, "docker", ["cp" | _], _}
    end

    test "Docker sync uses package-relative manifest paths", %{tmp_dir: tmp_dir} do
      source = Path.join(tmp_dir, "source")
      input = Path.join([source, "nested", "input"])
      dockerfile = Path.join(tmp_dir, "Dockerfile")
      File.mkdir_p!(Path.dirname(input))
      File.write!(input, "contents")
      File.write!(dockerfile, "FROM scratch\n")

      package = %{
        app: :test_package,
        deps: [],
        dockerfile: dockerfile,
        path: source,
        artifact_source_files: [input]
      }

      build_plan = %BuildPlan{packages: [package]}
      on_exit(fn -> File.rm_rf(Container.work_dir(package)) end)
      test_pid = self()

      stub(Nerves.MixUtils, :cmd, fn "docker", args, stderr_to_stdout: true ->
        manifest_mount =
          Enum.find(args, fn arg ->
            is_binary(arg) and String.ends_with?(arg, ",target=/nerves-sync,readonly")
          end)

        manifest_dir =
          manifest_mount
          |> String.replace_prefix("type=bind,src=", "")
          |> String.replace_suffix(",target=/nerves-sync,readonly", "")

        manifest = Path.join(manifest_dir, Path.basename(List.last(args)))
        send(test_pid, {:manifest, File.read!(manifest), Enum.at(args, -5)})
        {"", 0}
      end)

      assert :ok = Container.sync_work_dir(build_plan, "docker", package, "image")
      assert_received {:manifest, "nested/input\0", script}
      assert script =~ "-cf /tmp/nerves-sync.tar &&"
    end
  end
end
