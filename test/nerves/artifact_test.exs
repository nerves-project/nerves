defmodule Nerves.ArtifactTest do
  use NervesTest.Case, async: false

  alias Nerves.Artifact.Providers, as: P
  alias Nerves.Artifact
  alias Nerves.Env

  test "Fetch provider overrides" do
    in_fixture("package_provider_override", fn ->
      File.cwd!()
      |> Path.join("mix.exs")
      |> Code.require_file()

      Env.start()
      assert Env.package(:package_provider_override).provider == {P.Docker, []}
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
    {:ok, values} = Artifact.parse_download_name("package-name-portable-0.12.2-ABCDEF1234567890")
    assert String.equivalent?(values.app, "package-name")
    assert String.equivalent?(values.host_tuple, "portable")
    assert String.equivalent?(values.version, "0.12.2")
    assert String.equivalent?(values.checksum, "ABCDEF1234567890")
  end

  test "artifact_urls can only be binaries" do
    assert_raise Mix.Error, fn ->
      Artifact.expand_sites(%{config: [artifact_url: [{:broken}]]})
    end
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
