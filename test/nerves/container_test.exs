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
