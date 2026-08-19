# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.FingerprintTest do
  use ExUnit.Case, async: true

  alias Nerves.Fingerprint

  @moduletag :tmp_dir

  test "fingerprint and checksum are consistent", %{tmp_dir: tmp_dir} do
    file = Path.join(tmp_dir, "test.txt")
    File.write!(file, "test content")

    fingerprint = Fingerprint.fingerprint(["test.txt"], tmp_dir)
    checksum = Fingerprint.checksum(["test.txt"], tmp_dir)
    assert fingerprint == "2B60206"
    assert checksum == "2B60206C3F87E67012FBD30855E2571156EE504E7681D9344C02F8D6C094068F"
  end

  test "raises on missing files", %{tmp_dir: tmp_dir} do
    assert_raise File.Error, fn -> Fingerprint.fingerprint(["test.txt"], tmp_dir) end
  end

  test "handles multiple files", %{tmp_dir: tmp_dir} do
    File.write!(Path.join(tmp_dir, "file1.txt"), "content 1")
    File.write!(Path.join(tmp_dir, "file2.txt"), "content 2")

    result = Fingerprint.checksum(["file1.txt", "file2.txt"], tmp_dir)

    assert is_binary(result)
    assert String.length(result) == 64
  end

  test "handles glob patterns", %{tmp_dir: tmp_dir} do
    File.write!(Path.join(tmp_dir, "test1.txt"), "content 1")
    File.write!(Path.join(tmp_dir, "test2.txt"), "content 2")

    result = Fingerprint.fingerprint(["test*.txt"], tmp_dir)

    assert result == "25D2929"
  end

  test "handles directories", %{tmp_dir: tmp_dir} do
    subdir = Path.join(tmp_dir, "subdir")
    File.mkdir!(subdir)
    File.write!(Path.join(tmp_dir, "file1.txt"), "content 1")
    File.write!(Path.join(subdir, "file2.txt"), "content 2")

    result = Fingerprint.fingerprint(["subdir"], tmp_dir)

    assert result == "AE6CC57"
  end

  test "deduplicates expanded paths", %{tmp_dir: tmp_dir} do
    File.write!(Path.join(tmp_dir, "test.txt"), "content")

    result1 = Fingerprint.fingerprint(["test.txt", "test.txt"], tmp_dir)
    result2 = Fingerprint.fingerprint(["test.txt"], tmp_dir)

    assert result1 == result2
  end

  test "file order matters", %{tmp_dir: tmp_dir} do
    File.write!(Path.join(tmp_dir, "file1.txt"), "content 1")
    File.write!(Path.join(tmp_dir, "file2.txt"), "content 2")

    result1 = Fingerprint.checksum(["file1.txt", "file2.txt"], tmp_dir)
    result2 = Fingerprint.checksum(["file2.txt", "file1.txt"], tmp_dir)

    assert result1 != result2
  end

  test "fingerprint is first 7 chars of checksum", %{tmp_dir: tmp_dir} do
    file = Path.join(tmp_dir, "test.txt")
    File.write!(file, "test content")

    fingerprint = Fingerprint.fingerprint(["test.txt"], tmp_dir)
    checksum = Fingerprint.checksum(["test.txt"], tmp_dir)

    assert fingerprint == String.slice(checksum, 0, 7)
  end
end
