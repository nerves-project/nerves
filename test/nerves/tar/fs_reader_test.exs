# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Tar.FSReaderTest do
  use ExUnit.Case, async: true

  alias Nerves.Tar.FSReader

  @tmp_dir Path.join(System.tmp_dir!(), "nerves_tar_fsreader_test")

  setup do
    File.rm_rf!(@tmp_dir)
    File.mkdir_p!(@tmp_dir)

    # Create a small directory tree
    File.mkdir_p!(Path.join(@tmp_dir, "subdir"))
    File.write!(Path.join(@tmp_dir, "file.txt"), "hello")
    File.write!(Path.join([@tmp_dir, "subdir", "nested.txt"]), "nested")

    # Create a symlink
    File.ln_s!("file.txt", Path.join(@tmp_dir, "link.txt"))

    on_exit(fn -> File.rm_rf!(@tmp_dir) end)
    :ok
  end

  test "synthesize_dir/1" do
    entries = FSReader.synthesize_dirs("srv/erlang")

    assert length(entries) == 2

    [entry1, entry2] = entries

    assert entry1.type == :directory
    assert entry1.path == "./srv/"
    assert entry1.mode == 0o755

    assert entry2.type == :directory
    assert entry2.path == "./srv/erlang/"
    assert entry2.mode == 0o755
  end

  test "scans directory with default root" do
    entries = FSReader.scan_directory(@tmp_dir)

    paths = Enum.map(entries, & &1.path) |> Enum.sort()

    assert "./file.txt" in paths
    assert "./link.txt" in paths
    assert "./subdir/nested.txt" in paths

    # subdir should be a directory entry
    subdir = Enum.find(entries, &(&1.path == "./subdir/"))
    assert subdir.type == :directory
  end

  test "scans directory with custom root" do
    entries = FSReader.scan_directory(@tmp_dir, "srv/erlang")

    paths = Enum.map(entries, & &1.path) |> Enum.sort()

    assert "./srv/erlang/file.txt" in paths
    assert "./srv/erlang/link.txt" in paths
    assert "./srv/erlang/subdir/" in paths
    assert "./srv/erlang/subdir/nested.txt" in paths
  end

  test "regular files have correct size and contents reference" do
    entries = FSReader.scan_directory(@tmp_dir)

    file = Enum.find(entries, &(&1.path == "./file.txt"))
    assert file.type == :regular
    assert file.size == 5
    assert match?({path, 0} when is_binary(path), file.contents)
  end

  test "symlinks preserve link target" do
    entries = FSReader.scan_directory(@tmp_dir)

    link = Enum.find(entries, &(&1.path == "./link.txt"))
    assert link.type == :symlink
    assert link.link == "file.txt"
  end
end
