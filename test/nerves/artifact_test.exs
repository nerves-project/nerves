defmodule Nerves.ArtifactTest do
  use NervesTest.Case, async: false

  alias Nerves.Artifact.BuildRunners, as: P
  alias Nerves.Artifact
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

  test "parse artifact download name from regex" do
    {:ok, values} = Artifact.parse_download_name("package-name-portable-0.12.2-ABCDEF1")
    assert String.equivalent?(values.app, "package-name")
    assert String.equivalent?(values.host_tuple, "portable")
    assert String.equivalent?(values.version, "0.12.2")
    assert String.equivalent?(values.checksum, "ABCDEF1")
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
    pkg = %{
      app: "my_system",
      version: "1.0.0",
      path: "./",
      config: [artifact_sites: [{:github_releases, "nerves-project/system"}]]
    }

    checksum_long = Nerves.Artifact.checksum(pkg)
    checksum_short = Nerves.Artifact.checksum(pkg, short: 7)

    [{_, {short, _}}, {_, {long, _}}] = Artifact.expand_sites(pkg)

    assert String.ends_with?(short, checksum_short <> Artifact.ext(pkg))
    assert String.ends_with?(long, checksum_long <> Artifact.ext(pkg))
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
end
