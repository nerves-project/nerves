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
      validate_download!(package.download_validators, package, download, archive_path)
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

  defp validate_download!([], _package, _download, archive_path),
    do: validate_archive!(archive_path)

  defp validate_download!(validators, package, download, archive_path) do
    Enum.each(validators, fn
      :archive ->
        validate_archive!(archive_path)

      {:skip, options} ->
        _ = Keyword.fetch!(options, :filename)

      {:openssl_signature, options} ->
        filename = Keyword.fetch!(options, :filename)

        if filename == download.filename do
          validate_openssl_signature!(archive_path, package.download_path, filename, options)
        end
    end)
  end

  defp validate_archive!(archive_path) do
    case Archive.validate(archive_path) do
      :ok -> :ok
      {:error, reason} -> Mix.raise("Invalid artifact #{archive_path}: #{reason}")
    end
  end

  defp validate_openssl_signature!(path, download_path, filename, options) do
    signature_path =
      options
      |> Keyword.get(:signature, "#{filename}.sig")
      |> resolve_download_path(download_path)

    public_keys = Keyword.fetch!(options, :public_keys)
    signature = decode_signature!(signature_path)
    digest = sha256_file!(path)

    if not Enum.any?(public_keys, &verify_signature?(&1, digest, signature)) do
      Mix.raise("Invalid OpenSSL signature for #{path}")
    end
  end

  defp resolve_download_path(path, download_path) do
    if Path.type(path) == :absolute, do: path, else: Path.join(download_path, path)
  end

  defp decode_signature!(signature_path) do
    case Base.decode64(File.read!(signature_path), ignore: :whitespace) do
      {:ok, signature} -> signature
      :error -> Mix.raise("Could not decode OpenSSL signature #{signature_path}: invalid Base64")
    end
  end

  defp sha256_file!(path) do
    path
    |> File.stream!(64 * 1024, [])
    |> Enum.reduce(:crypto.hash_init(:sha256), &:crypto.hash_update(&2, &1))
    |> :crypto.hash_final()
  end

  defp verify_signature?(public_key, digest, signature) do
    [pem_entry] = :public_key.pem_decode(public_key)
    decoded_public_key = :public_key.pem_entry_decode(pem_entry)

    :public_key.verify({:digest, digest}, :sha256, signature, decoded_public_key)
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
