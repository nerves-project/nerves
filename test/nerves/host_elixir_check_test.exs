# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.HostElixirCheckTest do
  use ExUnit.Case, async: true

  alias Nerves.HostElixirCheck

  test "success case" do
    assert :ok = HostElixirCheck.check!()
  end
end
