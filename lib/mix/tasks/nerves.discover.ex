# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.Discover do
  @shortdoc "Discover Nerves devices on the local network"

  @moduledoc """
  Discover Nerves devices on the local network using mDNS

  This task scans the local network for Nerves devices and displays
  their information in a table format.

  Linux users: Install `avahi-utils` for faster responses.

  ## Examples

      $ mix nerves.discover

      $ mix nerves.discover --timeout 10000

  ## Options

    * `--timeout` - timeout in milliseconds to wait for replies (default 5000)
  """
  use Mix.Task

  @switches [timeout: :integer]

  @impl Mix.Task
  def run(argv) do
    {opts, _, _} = OptionParser.parse(argv, switches: @switches)
    timeout = Keyword.get(opts, :timeout, 5000)

    Mix.shell().info("\nDiscovering Nerves devices (waiting up to #{timeout}ms)...")

    devices = NervesDiscovery.discover(timeout: timeout)

    Mix.shell().info("")

    if Enum.empty?(devices) do
      Mix.shell().info("No devices found.")
    else
      Tablet.puts(devices, tablet_options(devices))
    end
  end

  defp tablet_options(devices) do
    base_columns = [:name, :addresses]

    optional_columns = [
      :serial,
      :version,
      :product,
      :platform,
      :uuid
    ]

    all_keys =
      Enum.reduce(devices, MapSet.new(), fn device, set ->
        set_put_many(set, non_empty_keys(device))
      end)

    # See which of the optional columns are actually present
    additional_columns =
      Enum.filter(optional_columns, &MapSet.member?(all_keys, &1))

    [
      keys: base_columns ++ additional_columns,
      formatter: &formatter/2,
      column_widths: %{uuid: :expand}
    ]
  end

  defp non_empty_keys(map) do
    Enum.reduce(map, [], fn {k, v}, acc -> if v != nil and v != "", do: [k | acc], else: acc end)
  end

  defp set_put_many(set, values), do: Enum.reduce(values, set, &MapSet.put(&2, &1))

  defp formatter(:__header__, key), do: {:ok, key |> to_string() |> String.upcase()}

  defp formatter(:addresses, addresses),
    do: {:ok, addresses |> Enum.map(&:inet.ntoa/1) |> Enum.map_join("\n", &to_string/1)}

  defp formatter(_, _), do: :default
end
