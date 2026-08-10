# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Artifact.ArchiveTest do
  use ExUnit.Case, async: true

  alias Nerves.Artifact.Archive

  @fixture_dir Path.expand("../../fixtures/resolver", __DIR__)
  @good_tar_gz Path.join(@fixture_dir, "artifact.tar.gz")
  @corrupt_tar_gz Path.join(@fixture_dir, "corrupt.tar.gz")

  describe "supported_extensions/0" do
    test "includes gz, xz, and zst" do
      exts = Archive.supported_extensions()
      assert ".tar.gz" in exts
      assert ".tar.xz" in exts
      assert ".tar.zst" in exts
    end
  end

  describe "file_type/1" do
    test "supported types" do
      assert Archive.file_type(Path.join(@fixture_dir, "artifact.tar")) == :tar
      assert Archive.file_type(Path.join(@fixture_dir, "artifact.gnutar")) == :tar
      assert Archive.file_type(Path.join(@fixture_dir, "artifact.oldtar")) == :tar
      assert Archive.file_type(Path.join(@fixture_dir, "artifact.tar.gz")) == :gzip
      assert Archive.file_type(Path.join(@fixture_dir, "artifact.tar.xz")) == :xz
      assert Archive.file_type(Path.join(@fixture_dir, "artifact.tar.zst")) == :zstd
      assert Archive.file_type(Path.join(@fixture_dir, "artifact.zip")) == :zip
      assert Archive.file_type(Path.join(@fixture_dir, "artifact.sqfs")) == :squashfs
    end

    test "bad path" do
      assert Archive.file_type(Path.join(@fixture_dir, "does_not_exist")) == :error
    end
  end

  describe "valid_name?/1" do
    test "accepts supported extensions" do
      assert Archive.valid_name?("foo.tar.gz")
      assert Archive.valid_name?("foo.tar.xz")
      assert Archive.valid_name?("foo.tar.zst")
    end

    test "rejects unsupported extensions" do
      refute Archive.valid_name?("foo.zip")
      refute Archive.valid_name?("foo.tar")
      refute Archive.valid_name?("foo.tar.bz2")
    end
  end

  describe "validate/1" do
    test "valid gzip archive passes" do
      assert :ok = Archive.validate(@good_tar_gz)
    end

    test "corrupt gzip archive fails" do
      assert {:error, _} = Archive.validate(@corrupt_tar_gz)
    end
  end

  describe "validate_dir/1" do
    test "returns corrupt files" do
      corrupt = Archive.validate_dir(@fixture_dir)
      paths = Enum.map(corrupt, fn {path, {:error, _}} -> Path.basename(path) end)

      assert "corrupt.tar.gz" in paths
      assert "corrupt.tar.xz" in paths
      assert "corrupt.tar.zst" in paths
      assert length(corrupt) == 3
    end
  end
end
