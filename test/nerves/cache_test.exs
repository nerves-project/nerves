defmodule Nerves.CacheTest do
  use NervesTest.Case, async: false

  alias Nerves.Artifact
  alias Nerves.Artifact.Cache

  test "cache entries are created properly" do
    in_fixture("host_tool", fn ->
      File.cwd!()
      |> Path.join("mix.exs")
      |> Code.require_file()

      Nerves.Env.start()
      package = Nerves.Env.package(:host_tool)

      artifact_name = Artifact.download_name(package) <> Artifact.ext(package)

      artifact_tar =
        File.cwd!()
        |> Path.join(artifact_name)

      Mix.Tasks.Deps.Get.run([])
      Mix.Tasks.Nerves.Artifact.run([])
      assert File.exists?(artifact_tar)

      Cache.put(package, artifact_tar)

      artifact_dir = Artifact.dir(package)

      assert File.dir?(artifact_dir)
      assert Cache.valid?(package)
    end)
  end
end
