# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.TargetTuple do
  @moduledoc """
  Utilities for figuring out compilation target tuples

  Fun rant: https://mcyoung.xyz/2025/04/14/target-triples/

  Standardizing on target tuple contents is hard
  so this module exists to convert tuples to whatever gets the
  job done. The pain is intended to be here, so that workarounds
  don't propagate everywhere.
  """

  @typedoc """
  Target tuple

  This contains the parsed `:erlang.system_info(:system_architecture)` results and
  is used for conversion to other formats.
  """
  defstruct [:arch, :vendor, :os, :abi]

  @type t() :: %__MODULE__{
          arch: String.t(),
          vendor: String.t(),
          os: String.t(),
          abi: nil | String.t()
        }

  @doc """
  Create a new tuple

  If an argument isn't passed, the host is queried.
  """
  @spec new(String.t() | charlist()) :: t()
  def new(system_architecture \\ :erlang.system_info(:system_architecture)) do
    case String.split(to_string(system_architecture), "-") do
      [arch, vendor, os, abi] -> %__MODULE__{arch: arch, vendor: vendor, os: os, abi: abi}
      [arch, vendor, os] -> %__MODULE__{arch: arch, vendor: vendor, os: os, abi: nil}
      _ -> %__MODULE__{arch: "unknown", vendor: "unknown", os: "unknown", abi: nil}
    end
  end

  @doc """
  Convert a target tuple back to it's :erlang.system_info(:system_architecture) form
  """
  @spec host_string(t()) :: String.t()
  def host_string(%__MODULE__{} = tuple) do
    [tuple.arch, tuple.vendor, tuple.os, tuple.abi]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("-")
  end

  @doc """
  Convert a host tuple into the tuple format used by Nerves v1 toolchain artifacts
  """
  @spec to_nerves_v1_host_tuple(t()) :: String.t() | :error
  def to_nerves_v1_host_tuple(%{os: "darwin" <> _, arch: "aarch64"}), do: "darwin_arm"
  def to_nerves_v1_host_tuple(%{os: "darwin" <> _, arch: "x86_64"}), do: "darwin_x86_64"
  def to_nerves_v1_host_tuple(%{os: "linux", arch: "aarch64", abi: "gnu"}), do: "linux_aarch64"
  def to_nerves_v1_host_tuple(%{os: "linux", arch: "x86_64", abi: "gnu"}), do: "linux_x86_64"
  def to_nerves_v1_host_tuple(_), do: :error
end
