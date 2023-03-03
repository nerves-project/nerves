defmodule Nerves.ArtifactTest do
  use NervesTest.Case

  alias Nerves.Artifact
  alias Nerves.Artifact.BuildRunners, as: P
  alias Nerves.Artifact.Resolvers.GithubAPI
  alias Nerves.Env

  test "Fetch build_runner overrides" do
    in_fixture("package_build_runner_override", fn ->
      File.cwd!()
      |> Path.join("mix.exs")
      |> Code.require_file()

      Env.start()
      assert Env.package(:package_build_runner_override).build_runner == {P.Docker, []}
    end)
  end

  test "build_runner_opts overrides" do
    in_fixture("package_build_runner_opts", fn ->
      File.cwd!()
      |> Path.join("mix.exs")
      |> Code.require_file()

      Env.start()
      assert {_, [make_args: []]} = Env.package(:package_build_runner_opts).build_runner
    end)
  end

  test "Resolve artifact path" do
    in_fixture("simple_app", fn ->
      packages = ~w(system toolchain)

      _ = load_env(packages)
      system = Env.package(:system)
      host_tuple = Artifact.host_tuple(system)
      artifact_dir = Artifact.dir(system)
      artifact_file = "#{system.app}-#{host_tuple}-#{system.version}"
      assert String.ends_with?(artifact_dir, artifact_file)
    end)
  end

  test "Override System and Toolchain path" do
    in_fixture("simple_app", fn ->
      packages = ~w(system toolchain)

      system_path =
        File.cwd!()
        |> Path.join("tmp/system")

      toolchain_path =
        File.cwd!()
        |> Path.join("tmp/toolchain")

      File.mkdir_p!(system_path)
      File.mkdir_p!(toolchain_path)

      System.put_env("NERVES_SYSTEM", system_path)
      System.put_env("NERVES_TOOLCHAIN", toolchain_path)

      _ = load_env(packages)

      assert Artifact.dir(Env.system()) == system_path
      assert Artifact.dir(Env.toolchain()) == toolchain_path
      assert Nerves.Env.toolchain_path() == toolchain_path
      assert Nerves.Env.system_path() == system_path
      System.delete_env("NERVES_SYSTEM")
      System.delete_env("NERVES_TOOLCHAIN")
    end)
  end

  test "artifact_urls can only be binaries" do
    assert_raise Mix.Error, fn ->
      Artifact.expand_sites(%{config: [artifact_url: [{:broken}]]})
    end
  end

  test "checksum short length" do
    in_fixture("system", fn ->
      File.cwd!()
      |> Path.join("mix.exs")
      |> Code.require_file()

      Nerves.Env.start()

      pkg = Nerves.Env.system()

      <<a::binary-size(7)-unit(8), _tail::binary>> = Nerves.Artifact.checksum(pkg)
      b = Nerves.Artifact.checksum(pkg, short: 7)

      assert String.equivalent?(a, b)
    end)
  end

  test "artifact sites are expanded" do
    repo = "nerves-project/system"

    pkg = %{
      app: "my_system",
      version: "1.0.0",
      path: "./",
      config: [artifact_sites: [{:github_releases, repo}]]
    }

    checksum_short = Nerves.Artifact.checksum(pkg, short: 7)

    [{GithubAPI, {^repo, opts}}] = Artifact.expand_sites(pkg)
    assert String.ends_with?(opts[:artifact_name], checksum_short <> Artifact.ext(pkg))
  end

  test "precompile will raise if packages are stale and not fetched" do
    in_fixture("simple_app_artifact", fn ->
      packages = ~w(system_artifact)
      _ = load_env(packages)

      Mix.Tasks.Nerves.Env.run([])

      assert_raise Mix.Error, fn ->
        Mix.Tasks.Nerves.Precompile.run([])
      end
    end)
  end

  test "parent projects are omitted from precompile check" do
    in_fixture("system_artifact", fn ->
      packages = ~w(toolchain system_platform)

      File.cwd!()
      |> Path.join("mix.exs")
      |> Code.require_file()

      _ = load_env(packages)

      Mix.Tasks.Deps.Get.run([])
      Mix.Tasks.Nerves.Env.run([])
      assert :ok = Mix.Tasks.Nerves.Precompile.run([])
    end)
  end

  describe "artifact base_path" do
    test "XDG_DATA_HOME" do
      System.delete_env("NERVES_ARTIFACTS_DIR")
      System.put_env("XDG_DATA_HOME", "xdg_data_home")
      assert "xdg_data_home/nerves/artifacts" = Nerves.Artifact.base_dir()
    end

    test "falls back to $HOME/.nerves" do
      System.delete_env("XDG_DATA_HOME")
      System.delete_env("NERVES_ARTIFACTS_DIR")
      assert Path.expand("~/.nerves/artifacts") == Nerves.Artifact.base_dir()
    end
  end
end
