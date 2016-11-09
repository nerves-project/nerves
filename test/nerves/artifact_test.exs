defmodule Nerves.ArtifactTest do
  use NervesTest.Case

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

  test "Resolve v1 artifact path" do
    in_fixture "simple_app_v1", fn ->
      packages =
        ~w(system_v1 toolchain_v1)

      _ = load_env(packages)
      system = Env.package(:system_v1)
      toolchain = Env.package(:toolchain_v1)
      artifact_dir = Artifact.dir(system, toolchain)
      v1_system_path =
        Mix.Project.build_path
        |> Path.join("nerves/system")
      assert artifact_dir == v1_system_path
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

      assert String.ends_with?(artifact_dir, "#{system.app}-#{system.version}.#{target_tuple}")
    end
  end
end
