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

    fingerprint = Fingerprint.fingerprint([file])
    checksum = Fingerprint.checksum([file])
    assert fingerprint == "2B60206"
    assert checksum == "2B60206C3F87E67012FBD30855E2571156EE504E7681D9344C02F8D6C094068F"
  end

  test "raises on missing files", %{tmp_dir: tmp_dir} do
    assert_raise File.Error, fn -> Fingerprint.fingerprint([Path.join(tmp_dir, "test.txt")]) end
  end

  test "file order matters", %{tmp_dir: tmp_dir} do
    file1 = Path.join(tmp_dir, "file1.txt")
    file2 = Path.join(tmp_dir, "file2.txt")
    File.write!(file1, "content 1")
    File.write!(file2, "content 2")

    result1 = Fingerprint.checksum([file1, file2])
    result2 = Fingerprint.checksum([file2, file1])

    assert result1 != result2
  end
end
