# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.BuildAction.RootfsTest do
  use ExUnit.Case, async: true

  alias Nerves.BuildAction.Rootfs

  describe "normalize_rootfs_type" do
    test "defaults to squashfs" do
      {default_type, default_args} = Rootfs.normalize_rootfs_type(nil)
      assert default_type == :squashfs
      assert is_list(default_args)
      assert Enum.all?(default_args, &is_binary/1)
    end

    test "known types return args" do
      for type <- [:squashfs, :erofs, :ext4] do
        {normalized_type, args} = Rootfs.normalize_rootfs_type(type)
        assert type == normalized_type
        assert is_list(args)
        assert Enum.all?(args, &is_binary/1)
      end
    end

    test "unknown type raises" do
      assert_raise Mix.Error, fn -> Rootfs.normalize_rootfs_type(:jffs) end
    end
  end
end
