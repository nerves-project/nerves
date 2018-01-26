defmodule Nerves.ArtifactTest do
  use NervesTest.Case, async: false

  alias Nerves.Artifact.Providers, as: P
  alias Nerves.Artifact
  alias Nerves.Env

  test "Fetch provider overrides" do
    in_fixture "package_provider_override", fn ->
      packages =
        ~w(package)
      _ = load_env(packages)
      
      assert Env.package(:package).provider == {P.Docker, []}
    end
  end

  test "Resolve artifact path" do
    in_fixture "simple_app", fn ->
      packages =
        ~w(system toolchain)

      _ = load_env(packages)
      system = Env.package(:system)
      host_tuple = Artifact.host_tuple(system)
      artifact_dir = Artifact.dir(system)
      artifact_file = "#{system.app}-#{host_tuple}-#{system.version}"
      assert String.ends_with?(artifact_dir, artifact_file)
    end
  end

  test "Override System and Toolchain path" do
    in_fixture "simple_app", fn ->
      packages =
        ~w(system toolchain)

      system_path =
        File.cwd!
        |> Path.join("tmp/system")

      toolchain_path =
        File.cwd!
        |> Path.join("tmp/toolchain")

      File.mkdir_p!(system_path)
      File.mkdir_p!(toolchain_path)

      System.put_env("NERVES_SYSTEM", system_path)
      System.put_env("NERVES_TOOLCHAIN", toolchain_path)


      _ = load_env(packages)

      assert Artifact.dir(Env.system) == system_path
      assert Artifact.dir(Env.toolchain) == toolchain_path

      System.delete_env("NERVES_SYSTEM")
      System.delete_env("NERVES_TOOLCHAIN")
    end
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
end
