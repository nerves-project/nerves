# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.ArtifactResolver do
  @moduledoc false

  alias Nerves.Artifact.Archive
  alias Nerves.BuildPlan

  @site_modules [
    Nerves.Artifact.Downloader.GitHub,
    Nerves.Artifact.Downloader.Gitea,
    Nerves.Artifact.Downloader.Prefix
  ]

  @fingerprint_filename ".fingerprint"

  @spec resolve(BuildPlan.t()) :: BuildPlan.t()
  def resolve(%BuildPlan{} = build_plan) do
    resolve_artifacts(build_plan)
  end

  defp resolve_artifacts(build_plan) do
    Enum.reduce(build_plan.packages, build_plan, fn package, plan ->
      Enum.reduce(package.downloads, plan, fn download, current_plan ->
        resolve_artifact(current_plan, package, download)
      end)
    end)
  end

  defp resolve_artifact(build_plan, _package, %{overridden?: true}), do: build_plan

  defp resolve_artifact(build_plan, package, download) do
    artifact_path = package.artifact_path
    fingerprint = package.source_fingerprint

    if valid_artifact?(artifact_path, fingerprint) do
      build_plan
    else
      archive_path = download_archive!(package, download)
      validate_archive!(:archive, archive_path)
      extract_archive!(List.first(package.extractors), archive_path, fingerprint)
      build_plan
    end
  end

  defp valid_artifact?(artifact_path, fingerprint) do
    File.read(Path.join(artifact_path, @fingerprint_filename)) == {:ok, fingerprint}
  end

  defp download_archive!(package, download) do
    archive_path = download.archive_path

    if File.exists?(archive_path) and Archive.validate(archive_path) == :ok do
      archive_path
    else
      File.mkdir_p!(Path.dirname(archive_path))
      download_from_sites!(package, download, archive_path)
      archive_path
    end
  end

  defp download_from_sites!(package, download, archive_path) do
    result =
      Enum.reduce_while(download.sites, {:error, :no_artifact_site}, fn site, _result ->
        case download_plan(site, download.version, download.filename) do
          nil ->
            {:cont, {:error, {:unsupported_site, site}}}

          {module, plan} ->
            case module.download(plan, archive_path) do
              :ok -> {:halt, :ok}
              {:error, reason} -> {:cont, {:error, reason}}
            end
        end
      end)

    case result do
      :ok ->
        :ok

      {:error, reason} ->
        nice_reason = if is_binary(reason), do: "\n\n" <> reason, else: inspect(reason)

        message = """
        Could not download #{download.filename}: #{nice_reason}

        It may also be possible to build this package manually by running:

        MIX_TARGET=#{Mix.target()} mix nerves.artifact.build #{package.app}
        """

        Mix.raise(message)
    end
  end

  defp download_plan(site, version, filename) do
    Enum.find_value(@site_modules, fn module -> module.plan(site, version, filename) end)
  end

  defp validate_archive!(:archive, archive_path) do
    case Archive.validate(archive_path) do
      :ok -> :ok
      {:error, reason} -> Mix.raise("Invalid artifact #{archive_path}: #{reason}")
    end
  end

  defp extract_archive!({:untar, options}, archive_path, fingerprint) do
    if archive_path != Keyword.fetch!(options, :source) do
      Mix.raise("Artifact extractor source does not match validated archive")
    end

    destination = Keyword.fetch!(options, :destination)
    _ = File.rm_rf!(destination)
    File.mkdir_p!(destination)

    case Archive.extract(archive_path, destination) do
      :ok -> File.write!(Path.join(destination, @fingerprint_filename), fingerprint)
      {:error, reason} -> Mix.raise("Could not extract #{archive_path}: #{reason}")
    end
  end
end
