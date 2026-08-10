# SPDX-FileCopyrightText: 2022 Jon Carstens
# SPDX-FileCopyrightText: 2022 Udo Schneider
# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.Artifact.Details do
  @shortdoc "Prints Nerves artifact details"
  @moduledoc """
  Print artifact details for all Nerves packages in the project's dependencies.

  ## Examples

      $ mix nerves.artifact.details

  """
  use Mix.Task

  alias Nerves.MixUtils

  @impl Mix.Task
  def run(_argv) do
    build_plan = Nerves.build_plan()

    packages_with_artifacts =
      Enum.filter(build_plan.packages, fn {_package, info} -> info.downloads != [] end)

    if packages_with_artifacts == [] do
      MixUtils.info(
        "No Nerves artifact packages found in project deps.\n" <>
          "Make sure MIX_TARGET is set (e.g., MIX_TARGET=rpi0)"
      )
    else
      Enum.each(packages_with_artifacts, &print_package_info/1)
    end

    :ok
  end

  defp print_package_info({package, info}) do
    MixUtils.info("#{package}:")
    MixUtils.info("  Version:            #{info.version}")
    MixUtils.info("  Source fingerprint: #{info.source_fingerprint}")
    MixUtils.info("  Fingerprint files:  #{length(info.source_fingerprint_files)} files")
    MixUtils.info("  Dependencies:       #{inspect(info.deps)}")

    MixUtils.info("  Downloads:")

    # TODO: add where the downloads are from. e.g., github releases
    Enum.each(info.downloads, fn download ->
      downloaded =
        if File.exists?(download.archive_path),
          do: "downloaded",
          else: "not downloaded"

      MixUtils.info("    #{download.filename} -> #{downloaded}")
    end)

    MixUtils.info("")
  end
end
