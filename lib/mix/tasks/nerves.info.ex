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
    with {:ok, hits} <- counter(r, "hits"),
         {:ok, misses} <- counter(r, "misses"),
         {:ok, fails} <- counter(r, "fails"),
         {:ok, lines} <- report_lines(Map.get(r, "lines")) do
      MixUtils.info("Precompiled:      #{hits} hit, #{misses} miss, #{fails} fail")

      for {n, v, s, d} <- lines, s != "hit" do
        MixUtils.info("  #{n} #{v}  #{String.upcase(s)}  #{d}")
      end
    else
      _ -> print_report(:error)
    end
  end

  defp print_report(:error), do: MixUtils.info("Precompiled:      report unreadable")

  defp counter(r, key) do
    case Map.get(r, key, 0) do
      n when is_integer(n) -> {:ok, n}
      _ -> :error
    end
  end

  defp report_lines(nil), do: {:ok, []}

  defp report_lines(lines) when is_list(lines) do
    lines
    |> Enum.reduce_while({:ok, []}, fn
      %{"name" => n, "version" => v, "status" => s, "detail" => d}, {:ok, acc}
      when is_binary(n) and is_binary(v) and is_binary(s) and is_binary(d) ->
        {:cont, {:ok, [{n, v, s, d} | acc]}}

      _, _ ->
        {:halt, :error}
    end)
    |> case do
      {:ok, acc} -> {:ok, Enum.reverse(acc)}
      :error -> :error
    end
  end

  defp report_lines(_), do: :error

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
