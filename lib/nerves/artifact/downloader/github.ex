# SPDX-FileCopyrightText: 2018 Justin Schneck
# SPDX-FileCopyrightText: 2018 Matt Ludwigs
# SPDX-FileCopyrightText: 2022 Frank Hunleth
# SPDX-FileCopyrightText: 2023 Jon Carstens
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Artifact.Downloader.GitHub do
  @moduledoc false

  alias Nerves.HTTPClient
  alias Nerves.MixUtils

  @github_url "https://github.com"
  @github_api_url "https://api.github.com"

  defstruct [
    :api_url,
    :web_url,
    :org_repo,
    :custom_auth_token,
    :artifact_filename,
    :tag,
    :method,
    :use_gh_cli?
  ]

  @doc """
  Build a download plan for a GitHub site (phase 1, pure).

  Returns `{module, plan}` or `nil`.
  """
  @spec plan(tuple(), String.t(), String.t()) :: {module(), %__MODULE__{}} | nil
  def plan({:github_api, org_repo, opts}, version, artifact_filename) do
    {api_url, web_url} =
      case Keyword.get(opts, :github_url) do
        nil -> {URI.parse(@github_api_url), URI.parse(@github_url)}
        custom -> {URI.parse(custom), nil}
      end

    {__MODULE__,
     %__MODULE__{
       api_url: api_url,
       web_url: web_url,
       org_repo: org_repo,
       custom_auth_token: opts[:token],
       artifact_filename: artifact_filename,
       tag: Keyword.get(opts, :tag, "v#{version}"),
       method: :github_api,
       use_gh_cli?: Keyword.get(opts, :use_gh_cli?, true)
     }}
  end

  def plan({:github_releases, org_repo}, version, artifact_filename) do
    plan({:github_releases, org_repo, []}, version, artifact_filename)
  end

  def plan({:github_releases, org_repo, opts}, version, artifact_filename) do
    {api_url, web_url} =
      case Keyword.get(opts, :github_url) do
        nil -> {URI.parse(@github_api_url), URI.parse(@github_url)}
        custom -> {nil, URI.parse(custom)}
      end

    {__MODULE__,
     %__MODULE__{
       api_url: api_url,
       web_url: web_url,
       org_repo: org_repo,
       custom_auth_token: opts[:token],
       artifact_filename: artifact_filename,
       tag: Keyword.get(opts, :tag, "v#{version}"),
       method: :github_release,
       use_gh_cli?: Keyword.get(opts, :use_gh_cli?, true)
     }}
  end

  def plan(_site, _version, _artifact_filename), do: nil

  @doc """
  Execute a single GitHub download plan (phase 2, HTTP).
  """
  @spec download(%__MODULE__{}, String.t()) :: :ok | {:error, term()}
  def download(%__MODULE__{} = plan, dest_path) do
    info =
      if System.get_env("NERVES_DEBUG") == "1",
        do: "#{plan.org_repo} #{plan.tag}/#{plan.artifact_filename}",
        else: plan.artifact_filename

    MixUtils.info(["  [GitHub] ", info])

    auth_token = get_auth_token(plan)

    auth_headers =
      if auth_token,
        do: [{"Authorization", "Bearer " <> auth_token}],
        else: []

    case do_download(plan.method, plan, dest_path, auth_headers) do
      :ok ->
        :ok

      {:error, reason} ->
        elided_token = if auth_token, do: String.slice(auth_token, 0, 6) <> "...", else: "unset"

        check_message =
          if plan.web_url,
            do: """
            Check the release page for available artifacts:
              #{URI.to_string(plan.web_url)}/#{plan.org_repo}/releases/tag/#{plan.tag}
            """,
            else: ""

        {:error,
         """
         Download failed: #{reason}

         If this is a private repository or you're getting rate limited, please check
         if you have a GitHub auth token. Nerves supports the `GITHUB_TOKEN` and `GH_TOKEN`
         environment variables and can call the GitHub CLI to find it. Alternatively, you
         can set a default strategy in your Nerves package's `artifact_sites` specification.
         For private repositories, `:github_api` is the recommended strategy.
         `:github_release` may work with authentication, but release downloads can still
         fail depending on GitHub's access controls and behavior.

         This failure was specifically for downloading #{plan.artifact_filename}. Other
         files could have been tried.

         #{check_message}
         Download method: #{plan.method}
         Web endpoint: #{safe_uri_to_string(plan.web_url)}
         API endpoint: #{safe_uri_to_string(plan.api_url)}
         Repository: #{plan.org_repo}
         Release tag: #{plan.tag}
         GitHub auth token: #{elided_token}
         """}
    end
  end

  defp safe_uri_to_string(nil), do: "nil"
  defp safe_uri_to_string(uri), do: URI.to_string(uri)

  defp do_download(:github_release, plan, dest_path, auth_headers) do
    download_url =
      URI.append_path(
        plan.web_url,
        "/#{plan.org_repo}/releases/download/#{plan.tag}/#{plan.artifact_filename}"
      )

    result = HTTPClient.download(download_url, dest_path, headers: auth_headers)

    if match?({:error, _}, result) and auth_headers != [] and plan.api_url != nil do
      # Fall back to API if we have an auth token and know the API URL
      do_download(:github_api, plan, dest_path, auth_headers)
    else
      result
    end
  end

  defp do_download(:github_api, plan, dest_path, auth_headers) do
    release_url =
      URI.append_path(plan.api_url, "/repos/#{plan.org_repo}/releases/tags/#{plan.tag}")

    with {:ok, release} <- HTTPClient.get_json(release_url, headers: auth_headers),
         {:ok, asset_api_url} <- find_asset_url(release, plan.artifact_filename) do
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

  defp find_asset_url(release, filename) do
    {:error,
     "Unexpected GitHub release response while looking for asset '#{filename}': " <>
       "missing \"assets\" list in #{inspect(release)}"}
  end

  defp get_auth_token(plan) do
    # Environment variables always override. gh is used last.
    System.get_env("GITHUB_TOKEN") || System.get_env("GH_TOKEN") || plan.custom_auth_token ||
      (plan.use_gh_cli? && gh_token())
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
