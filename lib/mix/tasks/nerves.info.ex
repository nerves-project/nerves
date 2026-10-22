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
        r = :json.decode(body)

        MixUtils.info(
          "Precompiled:      #{r["hits"]} hit, #{r["misses"]} miss, #{r["fails"]} fail"
        )

        for %{"name" => n, "version" => v, "status" => s, "detail" => d} <- r["lines"],
            s != "hit" do
          MixUtils.info("  #{n} #{v}  #{String.upcase(s)}  #{d}")
        end

      _ ->
        MixUtils.info("Precompiled:      not used")
    end
  end

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
