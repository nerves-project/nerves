# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.EnvHelpers do
  @moduledoc false
  import ExUnit.Callbacks

  @spec delete_env(String.t()) :: :ok
  def delete_env(name) when is_binary(name) do
    case System.get_env(name) do
      nil ->
        :ok

      value ->
        System.delete_env(name)
        on_exit(fn -> System.put_env(name, value) end)
    end
  end

  @spec put_env(String.t(), String.t() | nil) :: :ok
  def put_env(name, value) when is_binary(name) and is_binary(value) do
    case System.get_env(name) do
      nil -> on_exit(fn -> System.delete_env(name) end)
      old_value -> on_exit(fn -> System.put_env(name, old_value) end)
    end

    System.put_env(name, value)
  end

  def put_env(name, nil), do: delete_env(name)

  @spec put_env(map()) :: :ok
  def put_env(map) do
    Enum.each(map, fn {k, v} -> put_env(k, v) end)
  end
end
