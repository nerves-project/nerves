# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.BuildAction.FirmwareTest do
  use ExUnit.Case, async: true

  alias Nerves.BuildAction.Firmware
  alias Nerves.BuildPlan

  test "best compression is the default" do
    assert Firmware.default_config().fwup_compression == :best
  end

  test "rejects invalid compression options" do
    config =
      Firmware.default_config()
      |> Map.merge(%{
        fwup_conf: "fwup.conf",
        fwup_provisioning_conf: "provisioning.conf",
        source_date_epoch: nil,
        fwup_compression: 11
      })

    assert_raise Nerves.InvalidPlan, ~r/Expected :fast or :best/, fn ->
      Firmware.validate!(%BuildPlan{config: config})
    end
  end
end
