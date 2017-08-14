defmodule Nerves.ArtifactTest do
  use NervesTest.Case, async: false

  alias Nerves.Package.Providers, as: P
  alias Nerves.Package.Artifact
  alias Nerves.Env

  test "Fetch provider overrides" do
    in_fixture "artifact_override", fn ->
      packages =
        ~w(system toolchain package)
        |> Enum.sort

      _ = load_env(packages)

      assert Env.package(:system).provider == {P.Docker, []}
      assert Env.package(:toolchain).provider == {P.HTTP, url: "http://foo.bar/artifact.tar.gz"}
      assert Env.package(:package).provider == {P.Path, path: "/path/to/artifact"}
    end
  end

  test "Resolve artifact path" do
    in_fixture "simple_app", fn ->
      packages =
        ~w(system toolchain)

      _ = load_env(packages)
      system = Env.package(:system)
      toolchain = Env.package(:toolchain)
      target_tuple = toolchain.config[:target_tuple]
      artifact_dir = Artifact.dir(system, toolchain)
      artifact_file = "#{system.app}-#{system.version}.#{target_tuple}"
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

      assert Artifact.dir(Env.system, Env.toolchain) == system_path
      assert Artifact.dir(Env.toolchain, Env.toolchain) == toolchain_path

      System.delete_env("NERVES_SYSTEM")
      System.delete_env("NERVES_TOOLCHAIN")
    end
  end

  @tag :skip
  test "tar file error detection" do
      pkg =
      %Nerves.Package{app: :nerves_system_rpi3,
                      config: [artifact_url: ["https://github.com/nerves-project/nerves_system_rpi3/releases/download/v0.10.0/nerves_system_rpi3-v0.10.0.fw"],
                               platform_config: [defconfig: "nerves_defconfig"],
                               checksum: []],
                      dep: :hex,
                      path: "",
                      provider: [{Nerves.Package.Providers.HTTP, []}],
                      type: :system,
                      version: "0.10.0"}

      assert  :error  == Nerves.Package.artifact(pkg, %Nerves.Package{})
  end
end
