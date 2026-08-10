# SPDX-FileCopyrightText: 2016 Justin Schneck
# SPDX-FileCopyrightText: 2018 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Package.Platform do
  @moduledoc false

  # Do not use this module any more.

  @callback bootstrap(term()) :: :ok | {:error, error :: term()}
  @callback build_path_link(term()) :: build_path_link :: String.t()

  # This is used by nerves_toolchain_ctng which is still in use by many toolchains.
  defmacro __using__(_) do
    quote do
      @behaviour Nerves.Artifact.BuildRunner
      @behaviour Nerves.Package.Platform
    end
  end
end
