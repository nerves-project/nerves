# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Fwup.Word34567Test do
  use ExUnit.Case

  alias Nerves.Fwup.Word34567

  doctest Nerves.Fwup.Word34567

  test "words match C versions" do
    words = File.read!("test/fixtures/fwup/word34567.txt") |> String.split() |> Enum.with_index()

    Enum.each(words, fn {word, index} ->
      assert Word34567.word(index) == word
    end)
  end

  test "invalid indices raise" do
    assert_raise FunctionClauseError, fn -> Word34567.word(-1) end
    assert_raise FunctionClauseError, fn -> Word34567.word(256) end
  end
end
