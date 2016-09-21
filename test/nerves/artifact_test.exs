defmodule Nerves.ArtifactTest do
  use NervesTest.Case

  alias Nerves.Package.Providers, as: P
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
end
