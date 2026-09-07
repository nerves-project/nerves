# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Fingerprint do
  # The checksum covers the files listed in the package's `artifact_source_files`.
  # Each file is individually SHA256-hashed, then all hashes are concatenated
  # and hashed again.
  #
  # This is NOT a security feature. It helps guard against using stale build artifacts.
  @moduledoc false

  @spec fingerprint([String.t()]) :: String.t()
  def fingerprint(files) do
    files
    |> checksum()
    |> String.slice(0, 7)
  end

  @doc """
  Compute a SHA256-based checksum over a list of source files
  """
  @spec checksum([String.t()]) :: String.t()
  def checksum(files) do
    blob =
      files
      |> Enum.map(&File.read!/1)
      |> Enum.map(&:crypto.hash(:sha256, &1))

    :crypto.hash(:sha256, blob)
    |> Base.encode16()
  end
end
