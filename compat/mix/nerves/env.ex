# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Env do
  @moduledoc false

  @doc false
  @spec firmware_path() :: String.t()
  def firmware_path() do
    Nerves.build_plan().config[:firmware_path] |> Path.expand()
  end
end
