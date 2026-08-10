# SPDX-FileCopyrightText: 2016 Justin Schneck
# SPDX-FileCopyrightText: 2022 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Artifact.BuildRunner do
  @moduledoc false

  # Do not use this module any more.

  # It exists solely to support warning-free compilation of old artifacts

  @type build_result :: {:ok, build_path :: String.t()} | {:error, reason :: term}
  @type archive_result :: {:ok, path :: String.t()} | {:error, reason :: term}
  @type clean_result :: :ok | {:error, reason :: term}

  @callback build(package :: term(), toolchain :: term(), opts :: term()) :: term
  @callback archive(package :: term(), toolchain :: term(), opts :: term()) :: term
  @callback clean(package :: term()) :: term
end
