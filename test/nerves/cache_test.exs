# SPDX-FileCopyrightText: 2018 Justin Schneck
# SPDX-FileCopyrightText: 2020 Frank Hunleth
# SPDX-FileCopyrightText: 2022 Jon Carstens
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.CacheTest do
  use NervesTest.Case

  alias Nerves.Artifact
  alias Nerves.Artifact.Cache

  defp create_tgz(path, contents) do
    char_contents =
      Enum.map(contents, fn {entry_path, entry_contents} ->
        {to_charlist(entry_path), entry_contents}
      end)

    :ok = :erl_tar.create(to_charlist(path), char_contents, [:compressed])
  end

  @tag :tmp_dir
  test "cache entries are created properly", %{tmp_dir: tmp} do
    package = %Nerves.Package{
      path: tmp,
      version: "0.1.0",
      app: :tester,
      config: [checksum: ["tester"]]
    }

    artifact_name = Artifact.archive_name(package)
    artifact_tar = Path.join(tmp, artifact_name)

    create_tgz(artifact_tar, [{"artifact/tester", ""}])

    Cache.put(package, artifact_tar)

    artifact_dir = Artifact.dir(package)

    assert File.dir?(artifact_dir)
    assert Cache.valid?(package)
  end

  test "dl folder is queried prior to calling resolver" do
    in_fixture("system", fn ->
      File.cwd!()
      |> Path.join("mix.exs")
      |> Code.require_file()

      package = Nerves.Env.package(:system)

      dl_name = Nerves.Artifact.archive_basename(package) <> ".tar.gz"
      dl_path = Path.join(Nerves.Env.download_dir(), dl_name)

      File.mkdir_p!(Nerves.Env.download_dir())
      create_tgz(dl_path, [])

      System.delete_env("NERVES_SYSTEM")

      Mix.Tasks.Nerves.Artifact.Get.get(:system)
      output = "  => Trying #{dl_path}"
      assert_receive {:mix_shell, :info, [^output]}
      assert_receive {:mix_shell, :info, ["  Checking system..."]}
      assert_receive {:mix_shell, :info, ["  => Success"]}
      refute_receive _
    end)
  end

  test "corrupted downloads are validated on get and removed" do
    in_fixture("system", fn ->
      File.cwd!()
      |> Path.join("mix.exs")
      |> Code.require_file()

      package = Nerves.Env.package(:system)

      dl_name = Nerves.Artifact.archive_name(package)
      dl_path = Path.join(Nerves.Env.download_dir(), dl_name)
      File.mkdir_p!(Nerves.Env.download_dir())

      File.touch(dl_path)
      assert File.exists?(dl_path)

      # This might be leftover from previous test so we need to delete it
      # here to prevent the code path from resolving to another existing
      # test artifact and ensure it tries to resolve our corrupted download
      System.delete_env("NERVES_SYSTEM")
      Mix.Tasks.Nerves.Artifact.Get.get(:system)
      refute File.exists?(dl_path)
    end)
  end

  test "skip fetching packages that have paths set in the env" do
    in_fixture("system", fn ->
      File.cwd!()
      |> Path.join("mix.exs")
      |> Code.require_file()

      File.mkdir_p!(Nerves.Env.download_dir())

      System.put_env("NERVES_SYSTEM", Nerves.Env.download_dir())
      Mix.Tasks.Nerves.Artifact.Get.get(:system)
      message = "      " <> Nerves.Env.download_dir()
      assert_receive {:mix_shell, :info, [^message]}, 100
      System.delete_env("NERVES_SYSTEM")
    end)
  end
end
