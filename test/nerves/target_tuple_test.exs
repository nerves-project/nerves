# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#

defmodule Nerves.TargetTupleTest do
  use ExUnit.Case, async: true

  alias Nerves.TargetTuple

  test "new/0" do
    tuple = TargetTuple.new()

    assert is_struct(tuple, TargetTuple)
  end

  describe "to_nerves_v1_host_tuple/1" do
    defp to_nerves_v1_host_tuple(input) do
      input |> TargetTuple.new() |> TargetTuple.to_nerves_v1_host_tuple()
    end

    test "converts tuples to Nerves v1 toolchain tuples" do
      assert to_nerves_v1_host_tuple("aarch64-apple-darwin25.5.0") == "darwin_arm"
      assert to_nerves_v1_host_tuple("x86_64-apple-darwin23.6.0") == "darwin_x86_64"
      assert to_nerves_v1_host_tuple("x86_64-pc-linux-gnu") == "linux_x86_64"
      assert to_nerves_v1_host_tuple("aarch64-unknown-linux-gnu") == "linux_aarch64"
    end

    test "returns error on unknown platforms" do
      assert to_nerves_v1_host_tuple("aarch64-unknown-linux-musl") == :error
      assert to_nerves_v1_host_tuple("riscv64-unknown-linux-gnu") == :error
    end
  end
end
