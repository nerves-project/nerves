# SPDX-FileCopyrightText: 2018 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Nerves.Utils do
  @moduledoc false

  # This is required for nerves_toolchain_ctng even though the functions aren't called.
  # The gcc 15.3.0 and later toolchains don't use nerves_toolchain_ctng at all.

  @doc false
  @spec shell(binary(), [binary()], keyword()) :: {Collectable.t(), non_neg_integer()}
  def shell(_cmd, _args, _opts \\ []) do
    {"Don't call Mix.Nerves.Utils.shell any more", 1}
  end
end
