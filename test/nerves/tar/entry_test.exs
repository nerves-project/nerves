# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Tar.EntryTest do
  use ExUnit.Case, async: true

  alias Nerves.Tar.Entry

  describe "regular/2" do
    test "normalizes path and strips high mode bits" do
      entry = Entry.regular("/etc/config", contents: {"file", 0}, mode: 0o100644, size: 100)
      assert entry.path == "./etc/config"
      assert entry.mode == 0o644
      assert entry.type == :regular
      assert entry.size == 100
    end

    test "handles ./ prefix" do
      entry = Entry.regular("./bin/app", contents: {"file", 0}, mode: 0o755, size: 10)
      assert entry.path == "./bin/app"
    end
  end

  describe "directory/2" do
    test "appends trailing slash" do
      entry = Entry.directory("/usr/bin", mode: 0o755)
      assert entry.path == "./usr/bin/"
      assert entry.type == :directory
    end

    test "preserves existing trailing slash" do
      entry = Entry.directory("./etc/", mode: 0o755)
      assert entry.path == "./etc/"
    end
  end

  describe "symlink/2" do
    test "stores link target" do
      entry = Entry.symlink("/dev/ttyABC", mode: 0o777, link: "ttyS0")
      assert entry.path == "./dev/ttyABC"
      assert entry.type == :symlink
      assert entry.link == "ttyS0"
    end
  end

  describe "block_device/2" do
    test "stores major and minor device numbers" do
      entry = Entry.block_device("/dev/sda", mode: 0o660, major_device: 8, minor_device: 0)
      assert entry.path == "./dev/sda"
      assert entry.type == :block_device
      assert entry.major_device == 8
      assert entry.minor_device == 0
    end
  end

  describe "character_device/2" do
    test "stores major and minor device numbers" do
      entry =
        Entry.character_device("/dev/ttyS0", mode: 0o660, major_device: 4, minor_device: 64)

      assert entry.path == "./dev/ttyS0"
      assert entry.type == :character_device
      assert entry.major_device == 4
      assert entry.minor_device == 64
    end
  end

  describe "put_path/2" do
    test "updates and normalizes path" do
      entry = Entry.regular("./old", contents: {"f", 0}, mode: 0o644, size: 0)
      updated = Entry.put_path(entry, "/new/path")
      assert updated.path == "./new/path"
    end
  end

  describe "read_contents/1" do
    test "nil contents returns empty binary" do
      entry = %Entry{contents: nil}
      assert Entry.read_contents(entry) == {:ok, <<>>}
    end

    test "reads from file path" do
      tmp = Path.join(System.tmp_dir!(), "nerves_tar_entry_test")
      File.write!(tmp, "hello world")

      entry = %Entry{contents: {tmp, 0}, size: 5}
      assert Entry.read_contents(entry) == {:ok, "hello"}

      entry_offset = %Entry{contents: {tmp, 6}, size: 5}
      assert Entry.read_contents(entry_offset) == {:ok, "world"}

      File.rm!(tmp)
    end
  end

  test "rejects paths with ../" do
    assert_raise RuntimeError, ~r/Previous directory/, fn ->
      Entry.regular("../etc/passwd", contents: {"f", 0}, mode: 0o644, size: 0)
    end
  end
end
