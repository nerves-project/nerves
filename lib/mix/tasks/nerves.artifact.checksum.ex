# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.Nerves.Artifact.Checksum do
  @shortdoc "Generate checksums for Nerves artifact archives"
  @moduledoc """
  Generate `checksum.exs` for publishing a Nerves package to Hex

  Run `mix nerves.artifact.checksum` in a Nerves package, or
  `mix nerves.artifact.checksum PACKAGE` to select a dependency.
  Set `MIX_TARGET` as needed, just like other artifact tasks.

  Archives are derived from the selected package's build plan. Locally cached
  archives are used when available; missing archives are downloaded from the
  configured artifact sites. Signature sidecars aren't checksummed.
  Only archives in the active build plan are included, not all host platforms.

  This publisher-only task establishes the expected checksums, so it does not
  verify them against an existing manifest or extract artifacts. Only run it
  against artifacts you trust. The manifest is replaced, not merged.

  Enable checksum verification before building the artifacts. For Nerves v1
  systems, add `artifact_checksum: true` to `:nerves_package`.
  Nerves 2 packages can add `{:checksum, filename: filename}` validators.

  After generating and reviewing the manifest, include `"checksum.exs"` in
  the Hex package's `:files` list and publish it alongside the package sources.
  Nerves excludes files named `checksum.exs` from source fingerprints.
  """
  use Mix.Task

  alias Nerves.Artifact.Archive
  alias Nerves.Artifact.Checksum
  alias Nerves.ArtifactResolver
  alias Nerves.MixUtils

  @impl Mix.Task
  @spec run([String.t()]) :: :ok
  def run(args) do
    if length(args) > 1 or Enum.any?(args, &String.starts_with?(&1, "-")) do
      Mix.raise("Usage: mix nerves.artifact.checksum [PACKAGE]")
    end

    Mix.ensure_application!(:crypto)
    package = MixUtils.select_package!(Nerves.build_plan(), args)

    sources =
      Enum.map(package.extractors, fn {:untar, options} -> Keyword.fetch!(options, :source) end)

    if sources == [] do
      Mix.raise("No artifact archives found for #{package.app}")
    end

    manifest_path = Path.join(package.path, "checksum.exs")

    checksums =
      sources
      |> Enum.uniq()
      |> Map.new(fn source ->
        download =
          Enum.find(package.downloads, &(&1.archive_path == source)) ||
            Mix.raise("No artifact download found for #{source}")

        path = ArtifactResolver.download_file!(package, download)

        case Archive.validate(path) do
          :ok -> :ok
          {:error, reason} -> Mix.raise("Invalid artifact #{path}: #{reason}")
        end

        {download.filename, Checksum.checksum!(path)}
      end)

    Checksum.write!(manifest_path, checksums)
    MixUtils.info("Wrote artifact checksums to #{manifest_path}")
  end
end
