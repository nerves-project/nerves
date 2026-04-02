# SPDX-FileCopyrightText: 2018 Justin Schneck
# SPDX-FileCopyrightText: 2022 Frank Hunleth
# SPDX-FileCopyrightText: 2023 Jon Carstens
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Artifact.ArchiveTest do
  use NervesTest.Case

  alias Nerves.Artifact.Archive

  defp create_tgz(path, contents) do
    char_contents = Enum.map(contents, fn {path, contents} -> {to_charlist(path), contents} end)
    :ok = :erl_tar.create(to_charlist(path), char_contents, [:compressed])
  end

  test "supported_extensions/0" do
    assert Archive.supported_extensions() == [".tar.gz", ".tar.xz"]
  end

  test "decompress tar archives", context do
    in_tmp(context.test, fn ->
      archive = "archive.tar.gz"
      create_tgz(archive, [{"content/file", ""}])
      Archive.extract(archive, File.cwd!())
      assert File.exists?("file")
    end)
  end

  test "validate tar archives", context do
    in_tmp(context.test, fn ->
      cwd = File.cwd!()
      archive_path = Path.join(cwd, "archive.tar.gz")

      {_, 0} =
        System.cmd("dd", ["if=/dev/urandom", "bs=1024", "count=1", "of=#{archive_path}"],
          stderr_to_stdout: true
        )

      assert {:error, _} = Archive.validate(archive_path)
    end)
  end

  test "valid_name?/1" do
    assert Archive.valid_name?("abc.tar.gz")
    assert Archive.valid_name?("abc.tar.xz")
    refute Archive.valid_name?("abc")
    refute Archive.valid_name?("")
  end
end
