# SPDX-FileCopyrightText: 2023 James Harton
# SPDX-FileCopyrightText: 2024 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Artifact.Resolvers.GiteaAPI do
  @moduledoc false
  @behaviour Nerves.Artifact.Resolver

  alias Nerves.Utils.HTTPClient
  alias Nerves.Utils.Shell

  defstruct [:org_repo_url, :api_url, :auth_token, :artifact_filename, :tag, :method]

  @impl Nerves.Artifact.Resolver
  def plan({:gitea_releases, repo_uri}, version, artifact_filename) do
    plan({:gitea_releases, repo_uri, []}, version, artifact_filename)
  end

  def plan({:gitea_api, org_repo, opts}, version, artifact_filename) do
    base_url = Keyword.fetch!(opts, :base_url)
    base_uri = base_url |> String.trim_trailing("/") |> uri_parse_with_default_scheme()

    prepared = %__MODULE__{
      org_repo_url: URI.append_path(base_uri, "/" <> org_repo),
      api_url: URI.append_path(base_uri, "/api/v1/repos/" <> org_repo),
      auth_token: get_auth_token(opts),
      artifact_filename: artifact_filename,
      tag: Keyword.get(opts, :tag, "v#{version}"),
      method: :gitea_api
    }

    {__MODULE__, prepared}
  end

  def plan({:gitea_releases, repo_uri, opts}, version, artifact_filename) do
    prepared = %__MODULE__{
      org_repo_url: uri_parse_with_default_scheme(repo_uri),
      auth_token: get_auth_token(opts),
      artifact_filename: artifact_filename,
      tag: Keyword.get(opts, :tag, "v#{version}"),
      method: :gitea_release
    }

    {__MODULE__, prepared}
  end

  def plan(_site, _version, _artifact_filename), do: nil

  defp uri_parse_with_default_scheme(s) do
    with %URI{scheme: nil} <- URI.parse(s) do
      URI.parse("https://" <> s)
    end
  end

  @impl Nerves.Artifact.Resolver
  def get(%__MODULE__{} = opts, dest_path) do
    auth_headers =
      if opts.auth_token,
        do: [{"Authorization", "token " <> opts.auth_token}],
        else: []

    info =
      if System.get_env("NERVES_DEBUG") == "1",
        do: "#{URI.to_string(opts.org_repo_url)} #{opts.tag}/#{opts.artifact_filename}",
        else: opts.artifact_filename

    Shell.info(["  [Gitea] ", info])

    case download(opts.method, opts, dest_path, auth_headers) do
      :ok ->
        :ok

      {:error, reason} ->
        {:error,
         """
         Download failed: #{reason}

         If this is a private repository, please check that you have a Gitea auth token.
         Nerves checks the `GITEA_TOKEN` environment variable.
         Alternatively, you can set `token:` in your Nerves system's `artifact_sites` specification.
         `:gitea_releases` can work for private repositories when an auth token is provided.
         If direct authenticated release downloads do not work for your Gitea setup, try
         using `:gitea_api` instead.

         This failure was specifically for downloading #{opts.artifact_filename}. Other
         files could have been tried.

         Check the release page for available artifacts:
           "#{URI.to_string(opts.org_repo_url)}/releases/tag/#{opts.tag}"

         Download method: #{opts.method}
         """}
    end
  end

  defp download(:gitea_release, opts, dest_path, auth_headers) do
    download_url =
      URI.append_path(
        opts.org_repo_url,
        "/releases/download/#{opts.tag}/#{opts.artifact_filename}"
      )

    HTTPClient.download(download_url, dest_path, headers: auth_headers)
  end

  defp download(:gitea_api, opts, dest_path, auth_headers) do
    release_url = URI.append_path(opts.api_url, "/releases/tags/#{opts.tag}")

    with {:ok, release} <- HTTPClient.get_json(release_url, headers: auth_headers),
         {:ok, download_url} <- find_asset_url(release, opts.artifact_filename) do
      HTTPClient.download(download_url, dest_path, headers: auth_headers)
    end
  end

  defp find_asset_url(%{"assets" => assets}, filename) do
    case Enum.find(assets, fn a -> a["name"] == filename end) do
      %{"browser_download_url" => url} -> {:ok, url}
      nil -> {:error, "Asset '#{filename}' not found in release"}
    end
  end

  defp find_asset_url(release, filename) do
    {:error,
     "Unexpected Gitea release response while looking for asset '#{filename}': " <>
       "missing \"assets\" list in #{inspect(release)}"}
  end

  defp get_auth_token(opts) do
    env_token = System.get_env("GITEA_TOKEN")
    opts_token = opts[:token]

    cond do
      env_token != nil -> env_token
      opts_token != nil -> opts_token
      true -> nil
    end
  end
end
