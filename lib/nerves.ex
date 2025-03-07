# SPDX-FileCopyrightText: 2016 Justin Schneck
# SPDX-FileCopyrightText: 2022 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves do
  @moduledoc false

  @spec version() :: String.t()
  def version(), do: Application.spec(:nerves)[:vsn] |> to_string()
end
