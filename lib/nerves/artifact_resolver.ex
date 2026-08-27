# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.ArtifactResolver do
  @moduledoc false

  alias Nerves.Artifact.Archive
  alias Nerves.BuildPlan
  alias Nerves.MixUtils

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
    Enum.each(build_plan.packages, &resolve_package!/1)
    build_plan
  end

  defp resolve_package!(package) do
    downloads = Enum.reject(package.downloads, &Map.get(&1, :overridden?, false))

    if downloads != [] and
         not valid_artifact?(package.artifact_path, package.source_fingerprint) do
      download_paths = Enum.map(downloads, &download_file!(package, &1))

      Enum.each(downloads, fn download ->
        validate_download!(
          package.download_validators,
          package,
          download,
          download.archive_path
        )
      end)

      destinations =
        Enum.map(package.extractors, fn extractor ->
          extract_archive!(extractor, download_paths)
        end)

      Enum.each(destinations, fn destination ->
        File.write!(
          Path.join(destination, @fingerprint_filename),
          package.source_fingerprint
        )
      end)
    end
  end

  defp valid_artifact?(artifact_path, fingerprint) do
    File.read(Path.join(artifact_path, @fingerprint_filename)) == {:ok, fingerprint}
  end

  defp download_file!(package, download) do
    path = download.archive_path

    archive? =
      Enum.any?(package.extractors, fn {:untar, options} ->
        Keyword.fetch!(options, :source) == path
      end)

    if File.exists?(path) and (not archive? or Archive.validate(path) == :ok) do
      path
    else
      File.mkdir_p!(Path.dirname(path))
      download_from_sites!(package, download, path)
      path
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

  defp validate_download!(validators, package, download, archive_path) do
    validators =
      Enum.filter(validators, fn
        {type, options} when type in [:archive, :skip, :openssl_signature] ->
          Keyword.fetch!(options, :filename) == download.filename
      end)

    if validators == [] do
      Mix.raise("No download validator matches #{download.filename}")
    end

    Enum.each(validators, fn
      {:archive, _options} ->
        validate_archive!(archive_path)

      {:skip, _options} ->
        :ok

      {:openssl_signature, options} ->
        validate_openssl_signature!(archive_path, package, download, options)
    end)
  end

  defp validate_archive!(archive_path) do
    case Archive.validate(archive_path) do
      :ok -> :ok
      {:error, reason} -> Mix.raise("Invalid artifact #{archive_path}: #{reason}")
    end
  end

  defp validate_openssl_signature!(path, package, download, options) do
    MixUtils.info("  Verifying OpenSSL signature for #{download.filename}")

    public_keys = Keyword.fetch!(options, :public_keys)

    signature_path =
      options
      |> Keyword.get(:signature, "#{download.filename}.sig")
      |> resolve_download_path(package.download_path)

    if not File.exists?(signature_path) do
      Mix.raise("OpenSSL signature file does not exist: #{signature_path}")
    end

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

  defp extract_archive!({:untar, options}, download_paths) do
    archive_path = Keyword.fetch!(options, :source)

    if archive_path not in download_paths do
      Mix.raise("Artifact extractor source does not match validated archive")
    end

    destination = Keyword.fetch!(options, :destination)
    _ = File.rm_rf!(destination)
    File.mkdir_p!(destination)

    case Archive.extract(archive_path, destination) do
      :ok -> destination
      {:error, reason} -> Mix.raise("Could not extract #{archive_path}: #{reason}")
    end
  end
end
