# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Integration.HostToolingTest do
  use ExUnit.Case, async: false

  @artifact_app :nerves_host_tools
  @artifact_version "0.1.0"
  @artifact_output "_build/dev/lib/nerves_new_path_script/priv/compile_output.txt"

  # Allow a minute in case downloads are slow
  @test_timeout 120_000

  @tag :integration
  @tag timeout: @test_timeout
  test "host-tools Nerves package builds and can be used" do
    artifact_path = fixture_path("nerves_host_tools")
    project_path = fixture_path("nerves_new_path_script")

    clean_build!(artifact_path)
    clean_build!(project_path)
    clean_artifact!()

    run_mix_task!(artifact_path, "host", "deps.get")
    run_mix_task!(artifact_path, "host", "nerves.artifact.build")
    assert_host_archives!()

    run_mix_task!(project_path, "host", "deps.get")

    # Compilation step runs custom host tool
    run_mix_task!(project_path, "host", "compile")

    host_tuple =
      Nerves.TargetTuple.new()
      |> Nerves.TargetTuple.to_nerves_v1_host_tuple()

    assert File.read!(Path.join(project_path, @artifact_output)) == "#{host_tuple}\n"
  end

  defp clean_artifact!() do
    File.rm_rf!(Nerves.Paths.download_dir(@artifact_app, @artifact_version))
    File.rm_rf!(Nerves.Paths.artifact_dir(@artifact_app, @artifact_version))
  end

  defp clean_build!(path) do
    File.rm_rf!(Path.join(path, "_build"))
  end

  defp assert_host_archives!() do
    archive_names =
      @artifact_app
      |> Nerves.Paths.download_dir(@artifact_version)
      |> Path.join("*.tar.gz")
      |> Path.wildcard()
      |> Enum.map(&Path.basename/1)

    for host_tuple <- ["darwin_x86_64", "darwin_arm", "linux_x86_64", "linux_aarch64"] do
      assert Enum.any?(archive_names, &String.starts_with?(&1, "#{@artifact_app}-#{host_tuple}-"))
    end
  end

  defp run_mix_task!(path, target, task) do
    env = [{"MIX_ENV", "dev"}, {"MIX_TARGET", target}]
    {_, 0} = CoverHelper.mix([task], cd: path, env: env)
  end

  defp fixture_path(name) do
    Path.expand("../fixtures/build_plans/#{name}", __DIR__)
  end
end
