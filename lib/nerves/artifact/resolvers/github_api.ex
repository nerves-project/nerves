# SPDX-FileCopyrightText: 2018 Justin Schneck
# SPDX-FileCopyrightText: 2018 Matt Ludwigs
# SPDX-FileCopyrightText: 2022 Frank Hunleth
# SPDX-FileCopyrightText: 2023 Jon Carstens
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Artifact.Resolvers.GithubAPI do
  @moduledoc false
  @behaviour Nerves.Artifact.Resolver

  alias Nerves.Utils.HTTPClient
  alias Nerves.Utils.Shell

  @github_url "https://github.com"
  @github_api_url "https://api.github.com"

  defstruct [
    :github_url,
    :org_repo,
    :custom_auth_token,
    :artifact_filename,
    :tag,
    :method,
    :use_gh_cli?
  ]

  @impl Nerves.Artifact.Resolver
  def plan({:github_api, org_repo, opts}, version, artifact_filename) do
    github_url = Keyword.get(opts, :github_url, @github_api_url) |> URI.parse()

    prepared = %__MODULE__{
      github_url: github_url,
      org_repo: org_repo,
      custom_auth_token: opts[:token],
      artifact_filename: artifact_filename,
      tag: Keyword.get(opts, :tag, "v#{version}"),
      method: :github_api,
      use_gh_cli?: Keyword.get(opts, :use_gh_cli?, true)
    }

    {__MODULE__, prepared}
  end

  def plan({:github_releases, org_repo}, version, artifact_filename) do
    plan({:github_releases, org_repo, []}, version, artifact_filename)
  end

  def plan({:github_releases, org_repo, opts}, version, artifact_filename) do
    github_url = Keyword.get(opts, :github_url, @github_url) |> URI.parse()

    prepared = %__MODULE__{
      github_url: github_url,
      org_repo: org_repo,
      custom_auth_token: opts[:token],
      artifact_filename: artifact_filename,
      tag: Keyword.get(opts, :tag, "v#{version}"),
      method: :github_release,
      use_gh_cli?: Keyword.get(opts, :use_gh_cli?, true)
    }

    {__MODULE__, prepared}
  end

  def plan(_site, _version, _artifact_filename), do: nil

  @impl Nerves.Artifact.Resolver
  def get(%__MODULE__{} = opts, dest_path) do
    info =
      if System.get_env("NERVES_DEBUG") == "1",
        do: "#{opts.org_repo} #{opts.tag}/#{opts.artifact_filename}",
        else: opts.artifact_filename

    Shell.info(["  [GitHub] ", info])

    auth_token = get_auth_token(opts)

    auth_headers =
      if auth_token,
        do: [{"Authorization", "Bearer " <> auth_token}],
        else: []

    case download(opts.method, opts, dest_path, auth_headers) do
      :ok ->
        :ok

      {:error, reason} ->
        elided_token = if auth_token, do: String.slice(auth_token, 0, 6) <> "...", else: "unset"

        {:error,
         """
         Download failed: #{reason}

         If this is a private repository or you're getting rate limited, please check
         if you have a GitHub auth token. Nerves supports the `GITHUB_TOKEN` and `GH_TOKEN`
         environment variables and can call the GitHub CLI to find it. Alternatively, you
         can set a default strategy in your Nerves system's `artifact_sites` specification.
         For private repositories, `:github_api` is the recommended strategy.
         `:github_release` may work with authentication, but release downloads can still
         fail depending on GitHub's access controls and behavior.

         This failure was specifically for downloading #{opts.artifact_filename}. Other
         files could have been tried.

         Check the release page for available artifacts:
           "#{opts.github_url}/#{opts.org_repo}/releases/tag/#{opts.tag}"

         Download method: #{opts.method}
         GitHub auth token: #{elided_token}
         """}
    end
  end

  defp download(:github_release, opts, dest_path, auth_headers) do
    download_url =
      URI.append_path(
        opts.github_url,
        "/#{opts.org_repo}/releases/download/#{opts.tag}/#{opts.artifact_filename}"
      )

    HTTPClient.download(download_url, dest_path, headers: auth_headers)
  end

  defp download(:github_api, opts, dest_path, auth_headers) do
    release_url =
      URI.append_path(opts.github_url, "/repos/#{opts.org_repo}/releases/tags/#{opts.tag}")

    with {:ok, release} <- HTTPClient.get_json(release_url, headers: auth_headers),
         {:ok, asset_api_url} <- find_asset_url(release, opts.artifact_filename) do
      download_headers = [{"Accept", "application/octet-stream"} | auth_headers]
      HTTPClient.download(asset_api_url, dest_path, headers: download_headers)
    end
  end

  defp find_asset_url(%{"assets" => assets}, filename) do
    case Enum.find(assets, fn a -> a["name"] == filename end) do
      %{"url" => url} -> {:ok, url}
      nil -> {:error, "Asset '#{filename}' not found in release"}
    end
  end

  defp get_auth_token(opts) do
    # Environment variables always override. gh is used last.
    System.get_env("GITHUB_TOKEN") || System.get_env("GH_TOKEN") || opts.custom_auth_token ||
      (opts.use_gh_cli? && gh_token())
  end

  defp gh_token() do
    with gh when not is_nil(gh) <- System.find_executable("gh"),
         {result, 0} <- System.cmd(gh, ["auth", "token"]) do
      String.trim(result)
    else
      _err -> nil
    end
  end
end
