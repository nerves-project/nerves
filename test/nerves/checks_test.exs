defmodule Nerves.ChecksTest do
  use ExUnit.Case

  doctest Nerves.Checks

  test "compiler check passes" do
    assert Nerves.Checks.check_compiler!() == :ok
  end
end
