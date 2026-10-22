# SPDX-FileCopyrightText: 2017 Justin Schneck
# SPDX-FileCopyrightText: 2022 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.Info do
  @shortdoc "Prints Nerves information"

  @moduledoc """
  Prints Nerves system information.

      mix nerves.info

  """
  use Mix.Task

  alias Nerves.MixUtils

  @impl Mix.Task
  def run(_argv) do
    MixUtils.info("Nerves:           #{Nerves.version()}")
    MixUtils.info("Nerves Bootstrap: #{bootstrap_version()}")
    MixUtils.info("Elixir:           #{System.version()}")
    precompiled_info()
  end

  defp precompiled_info() do
    path = Path.join([Mix.Project.build_path(), "lib", ".precompiled", "report.json"])

    case File.read(path) do
      {:ok, body} ->
        print_report(decode_report(body))

      _ ->
        MixUtils.info("Precompiled:      not used")
    end
  end

  # A `report.json` is only ever written atomically (see `Nerves.Precompiled`),
  # but a diagnostic command must never crash on a file it didn't write, e.g.
  # one left behind by an older version or edited by hand.
  defp decode_report(body) do
    case :json.decode(body) do
      r when is_map(r) -> {:ok, r}
      _ -> :error
    end
  rescue
    _ -> :error
  end

  defp print_report({:ok, r}) do
    hits = Map.get(r, "hits", 0)
    misses = Map.get(r, "misses", 0)
    fails = Map.get(r, "fails", 0)
    lines = Map.get(r, "lines", []) || []

    MixUtils.info("Precompiled:      #{hits} hit, #{misses} miss, #{fails} fail")

    for %{"name" => n, "version" => v, "status" => s, "detail" => d} <- lines,
        s != "hit" do
      MixUtils.info("  #{n} #{v}  #{String.upcase(s)}  #{d}")
    end
  end

  defp print_report(:error), do: MixUtils.info("Precompiled:      report unreadable")

  defp bootstrap_version() do
    archives_path = Mix.path_for(:archives)
    prefix = Path.join(archives_path, "nerves_bootstrap")

    case Path.wildcard("#{prefix}*") do
      [] -> "not installed"
      [_, _ | _] -> "multiple installs?"
      [^prefix] -> "unspecified"
      [entry] -> String.trim_leading(entry, prefix <> "-")
    end
  end
end
