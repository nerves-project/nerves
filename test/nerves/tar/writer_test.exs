# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Tar.WriterTest do
  use ExUnit.Case, async: true

  alias Nerves.Tar.Writer

  test "padding_field/1 creates zero-filled binary" do
    assert Writer.padding_field(8) == <<0, 0, 0, 0, 0, 0, 0, 0>>
    assert Writer.padding_field(1) == <<0>>
    assert Writer.padding_field(0) == <<>>
  end

  test "string_field/2 null-pads to length" do
    assert Writer.string_field("abc", 8) == <<?a, ?b, ?c, 0, 0, 0, 0, 0>>
    assert Writer.string_field("", 4) == <<0, 0, 0, 0>>
  end

  test "string_field/2 truncates to length" do
    assert Writer.string_field("abcdef", 3) == <<?a, ?b, ?c>>
  end

  test "octal_field/2 formats with null terminator" do
    assert IO.iodata_to_binary(Writer.octal_field(0o755, 8)) == "0000755\0"
    assert IO.iodata_to_binary(Writer.octal_field(0, 8)) == "0000000\0"
  end

  test "zero_pad/2 pads correctly" do
    assert Writer.zero_pad("hi", 5) == <<?h, ?i, 0, 0, 0>>
    assert Writer.zero_pad("", 3) == <<0, 0, 0>>
  end
end
