# SPDX-FileCopyrightText: 2026 Frank Hunleth
# SPDX-FileCopyrightText: 2026 Jannik Becher
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.ContainerTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Nerves.BuildPlan
  alias Nerves.Container

  @moduletag :tmp_dir

  test "image fingerprint includes the entrypoint when present", %{tmp_dir: tmp_dir} do
    stub(Nerves.MixUtils, :cmd, fn "docker", ["image", "inspect", _image], _opts ->
      {"", 0}
    end)

    dockerfile = Path.join(tmp_dir, "Dockerfile")
    entrypoint = Path.join(tmp_dir, "nerves-artifact")
    File.write!(dockerfile, "FROM scratch\n")

    package =
      Nerves.BuildPlanHelpers.package_info(:test_package, tmp_dir, tmp_dir)
      |> Map.put(:dockerfile, dockerfile)

    image_without_entrypoint = Container.package_image!("docker", package)
    File.write!(entrypoint, "#!/bin/sh\nexit 0\n")
    image = Container.package_image!("docker", package)
    refute image == image_without_entrypoint
    assert Container.package_image!("docker", package) == image

    File.write!(entrypoint, "#!/bin/sh\nexit 1\n")
    refute Container.package_image!("docker", package) == image
  end

  test "ccache directory is mounted and configured only when enabled", %{tmp_dir: tmp_dir} do
    variables = ["NERVES_CCACHE_DIR", "NERVES_CCACHE_INITIAL_SETUP"]
    original = Enum.map(variables, &{&1, System.get_env(&1)})

    on_exit(fn ->
      Enum.each(original, fn {key, value} ->
        if value, do: System.put_env(key, value), else: System.delete_env(key)
      end)
    end)

    stub(Nerves.MixUtils, :cmd, fn _, _, _ -> {"", 0} end)
    package = Nerves.BuildPlanHelpers.package_info(:test_package, tmp_dir, tmp_dir)
    plan = %BuildPlan{config: %{host_tuple: Nerves.TargetTuple.new()}}
    cache = Path.join(tmp_dir, "compiler cache")
    System.put_env("NERVES_CCACHE_DIR", cache)
    System.put_env("NERVES_CCACHE_INITIAL_SETUP", "--max-size=2G")

    for tool <- ["docker", "podman", "container"] do
      args = Container.artifact_run_args(plan, package, tool, "image", "/downloads", ["build"])
      assert "CCACHE_DIR=/workspace/ccache" in args
      assert "NERVES_CCACHE_INITIAL_SETUP=--max-size=2G" in args

      if tool == "container" do
        assert "type=bind,source=#{cache},target=/workspace/ccache" in args
      else
        assert "#{cache}:/workspace/ccache" in args
      end

      assert File.dir?(cache)
    end

    System.delete_env("NERVES_CCACHE_INITIAL_SETUP")
    args = Container.artifact_run_args(plan, package, "docker", "image", "/downloads", ["build"])
    assert "NERVES_CCACHE_INITIAL_SETUP=--max-size=1G" in args

    for value <- [nil, ""] do
      if value,
        do: System.put_env("NERVES_CCACHE_DIR", value),
        else: System.delete_env("NERVES_CCACHE_DIR")

      args =
        Container.artifact_run_args(plan, package, "docker", "image", "/downloads", ["build"])

      refute Enum.any?(args, &String.contains?(&1, "CCACHE"))
    end
  end

  test "artifact arguments follow their respective commands", %{tmp_dir: tmp_dir} do
    stub(Nerves.MixUtils, :cmd, fn _, _, _ -> {"", 0} end)

    tool = "docker_stub_for_testing"
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
          tool,
          "image",
          "/downloads",
          commands
        )

      assert Enum.drop_while(args, &(&1 != "image")) == ["image" | expected]
    end

    package = %{package | artifact_command_args: %{}}

    args =
      Container.artifact_run_args(build_plan, package, tool, "image", "/downloads", ["build"])

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

    for {args, cache} <- [
          {make_args, nil},
          {[], nil},
          {make_args, Path.join(tmp_dir, "cache dir")}
        ] do
      File.write!(log, "")
      cache_env = [{"CCACHE_DIR", cache}, {"NERVES_CCACHE_INITIAL_SETUP", "--max-size=2G"}]

      assert {_, 0} =
               System.cmd("sh", [script, "build" | args],
                 env: env ++ cache_env,
                 stderr_to_stdout: true
               )

      args =
        if cache,
          do:
            args ++
              [
                "BR2_CCACHE=y",
                "BR2_CCACHE_DIR=#{cache}",
                "BR2_CCACHE_INITIAL_SETUP=--max-size=2G"
              ],
          else: args

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
      artifact_source_excludes: [],
      artifact_source_files: [input]
    }

    build_plan = %BuildPlan{packages: [package]}
    checksum = Container.workspace_checksum(build_plan, package)
    changed_fingerprint = %{package | source_fingerprint: "NEW"}

    assert Container.workspace_checksum(build_plan, changed_fingerprint) == checksum

    changed_excludes = %{package | artifact_source_excludes: ["./cache"]}
    changed_plan = %{build_plan | packages: [changed_excludes]}
    assert Container.workspace_checksum(changed_plan, changed_excludes) != checksum

    dependency = %{package | app: :test_dependency}
    package = %{package | deps: [:test_dependency]}
    build_plan = %{build_plan | packages: [package, dependency]}
    checksum = Container.workspace_checksum(build_plan, package)
    dependency = %{dependency | artifact_source_excludes: ["./cache"]}
    changed_plan = %{build_plan | packages: [package, dependency]}
    assert Container.workspace_checksum(changed_plan, package) != checksum
  end

  if :os.type() == {:unix, :linux} do
    test "Linux uses per-package exclusions and preserves build output", %{
      tmp_dir: tmp_dir
    } do
      source = Path.join(tmp_dir, "source")
      File.mkdir!(source)
      File.write!(Path.join(source, "input"), "contents")

      source_directories = [
        "buildroot",
        "buildroot-2026.05.3",
        "_build",
        "deps",
        ".git",
        ".nerves"
      ]

      for directory <- source_directories do
        File.mkdir!(Path.join(source, directory))
        File.write!(Path.join([source, directory, "Makefile"]), "package source")
      end

      File.mkdir!(Path.join(source, "cache"))

      dep_source = Path.join(tmp_dir, "dep")
      File.mkdir_p!(Path.join(dep_source, "buildroot-2026.05.3"))
      File.ln_s!("/host-only/buildroot-2026.05.3", Path.join(dep_source, "buildroot"))
      File.ln_s!("/host-only/.nerves/dl", Path.join(dep_source, "buildroot-2026.05.3/dl"))
      File.mkdir_p!(Path.join(dep_source, ".nerves"))
      File.mkdir_p!(Path.join(dep_source, "patches/buildroot"))
      File.write!(Path.join(dep_source, "patches/buildroot/fix.patch"), "patch")

      package = %{
        app: :test_package,
        deps: [:test_dependency],
        path: source,
        artifact_source_excludes: ["./cache"]
      }

      dep = %{
        app: :test_dependency,
        path: dep_source,
        artifact_source_excludes: ["./buildroot", "./buildroot-[0-9]*", "./.nerves"]
      }

      build_plan = %BuildPlan{packages: [package, dep]}
      workspace = Container.work_dir(package)
      on_exit(fn -> File.rm_rf(workspace) end)
      File.mkdir_p!(Path.join(workspace, "build"))
      File.write!(Path.join(workspace, "build/output"), "keep me")
      File.mkdir_p!(Path.join(workspace, "test_dependency"))
      File.ln_s!("/old-host/buildroot", Path.join(workspace, "test_dependency/buildroot"))

      assert :ok = Container.populate_work_dir(build_plan, "docker", package, "image")
      assert File.read!(Path.join(workspace, "test_package/input")) == "contents"

      for directory <- source_directories do
        assert File.read!(Path.join([workspace, "test_package", directory, "Makefile"])) ==
                 "package source"
      end

      refute File.exists?(Path.join(workspace, "test_package/cache"))
      assert File.ls!(Path.join(workspace, "test_dependency")) == ["patches"]

      assert File.read!(Path.join(workspace, "test_dependency/patches/buildroot/fix.patch")) ==
               "patch"

      assert File.read!(Path.join(workspace, "build/output")) == "keep me"
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
        artifact_source_excludes: [],
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

      package = %{app: :test_package, deps: [], path: source, artifact_source_excludes: []}
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
        artifact_source_excludes: [],
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
