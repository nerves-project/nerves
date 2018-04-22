defmodule Nerves.CacheTest do
  use NervesTest.Case, async: false

  alias Nerves.Artifact
  alias Nerves.Artifact.Cache

  test "cache entries are created properly" do
    in_fixture("host_tool", fn ->
      Application.start(:nerves_bootstrap)

      File.cwd!()
      |> Path.join("mix.exs")
      |> Code.require_file()

      Nerves.Env.start()
      package = Nerves.Env.package(:host_tool)

      artifact_name = Artifact.download_name(package) <> Artifact.ext(package)

      artifact_tar =
        File.cwd!()
        |> Path.join(artifact_name)

      Mix.Tasks.Nerves.Artifact.run([])
      assert File.exists?(artifact_tar)

      Cache.put(package, artifact_tar)

      artifact_dir = Artifact.dir(package)

      assert File.dir?(artifact_dir)
      assert Cache.valid?(package)
    end)
  end

  test "dl folder is queried prior to calling resolver" do
    in_fixture("system", fn ->
      File.cwd!()
      |> Path.join("mix.exs")
      |> Code.require_file()

      Nerves.Env.start()
      package = Nerves.Env.package(:system)

      dl_name = Nerves.Artifact.download_name(package) <> Nerves.Artifact.ext(package)
      dl_path = Path.join(Nerves.Env.download_dir(), dl_name)
      File.mkdir_p(Nerves.Env.download_dir())

      working_path = Path.join(File.cwd!(), "archive")
      File.mkdir_p(working_path)

      working_path
      |> Path.join("CHECKSUM")
      |> File.write(Nerves.Artifact.checksum(package))

      Nerves.Utils.File.tar(working_path, dl_path)

      Mix.Tasks.Nerves.Artifact.Get.get(:system, [])
      output = "  => Trying #{dl_path}"
      assert_received({:mix_shell, :info, [^output]})
    end)
  end
end
