# SPDX-FileCopyrightText: 2023 James Harton
# SPDX-FileCopyrightText: 2024 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Artifact.Downloaders.GiteaAPI do
  @moduledoc false
  @behaviour Nerves.Artifact.Downloader

  alias Nerves.Utils.HTTPClient
  alias Nerves.Utils.Shell

  defstruct dest_dir: nil,
            download_names: [],
            base_url: nil,
            headers: [],
            public?: false,
            opts: [],
            repo: nil,
            tag: "",
            token: "",
            url: nil

  @impl Nerves.Artifact.Downloader
  def expand_site({:gitea_releases, repo_uri}, info) when is_binary(repo_uri) do
    expand_gitea_releases(URI.parse(repo_uri), info)
  end

  def expand_site({:gitea_releases, %URI{} = repo_uri}, info) do
    expand_gitea_releases(repo_uri, info)
  end

  def expand_site({:gitea_api, org_proj, resolver_opts}, _info) do
    {:ok, {org_proj, resolver_opts}}
  end

  def expand_site(_site_config, _info), do: :skip

  @impl Nerves.Artifact.Downloader
  def download(repo, opts) do
    s =
      %{struct(__MODULE__, opts) | opts: opts, repo: repo}
      |> maybe_adjust_token()
      |> add_http_opts()

    fetch_artifact(s)
  end

  @impl Nerves.Artifact.Downloader
  def site_help() do
    [
      ~s({:gitea_releases, "host/owner/repo"}),
      ~s({:gitea_api, "owner/repo", base_url: "https://gitea.com", token: "123456", tag: "v0.1.0"})
    ]
  end

  # Private

  defp expand_gitea_releases(%URI{scheme: nil, host: nil, path: path}, info) do
    expand_gitea_releases(URI.parse("https://#{path}"), info)
  end

  defp expand_gitea_releases(%URI{} = repo_uri, info) do
    base_url = %{repo_uri | path: "/"} |> to_string()
    org_proj = repo_uri.path |> String.trim_leading("/")

    opts = [
      base_url: base_url,
      public?: true,
      tag: "v#{info[:version]}"
    ]

    {:ok, {org_proj, opts}}
  end

  defp add_http_opts(opts) do
    headers =
      if opts.public? do
        []
      else
        # make safe values here in case nil was supplied as an option
        # The request will fail and error will be reported later on
        token = opts.token || ""

        [{"Authorization", "token " <> token}]
      end

    %{
      opts
      | headers: headers,
        url:
          Path.join([
            opts.base_url,
            "api",
            "v1",
            "repos",
            opts.repo,
            "releases",
            "tags",
            opts.tag
          ])
    }
  end

  defp maybe_adjust_token(opts) do
    token = System.get_env("GITEA_TOKEN")

    if token do
      # Let the env var take precedence
      %{opts | token: token}
    else
      opts
    end
  end

  defp fetch_artifact(opts) do
    info = if System.get_env("NERVES_DEBUG") == "1", do: opts.url, else: hd(opts.download_names)

    Shell.info(["  [Gitea] ", info])

    case release_details(opts) do
      {:ok, %{"assets" => assets}} ->
        download_from_assets(assets, opts)

      {:error, _} = error ->
        error
    end
  end

  defp download_from_assets([], _opts), do: {:error, "No release artifacts"}

  defp download_from_assets(assets, opts) do
    case find_matching_asset(assets, opts.download_names) do
      {%{"browser_download_url" => url}, name} ->
        do_download(url, name, opts)

      nil ->
        available = for %{"name" => name} <- assets, do: ["       * ", name, "\n"]
        {:error, ["No artifact with valid checksum\n\n     Found:\n", available]}
    end
  end

  defp find_matching_asset(assets, download_names) do
    Enum.find_value(download_names, fn name ->
      asset = Enum.find(assets, fn %{"name" => n} -> String.equivalent?(name, n) end)
      if asset, do: {asset, name}
    end)
  end

  defp do_download(url, name, opts) do
    dest_path = Path.join(opts.dest_dir, name)
    http_opts = [headers: [{"Accept", "application/octet-stream"} | opts.headers]]

    case HTTPClient.download(url, dest_path, http_opts) do
      :ok -> {:ok, dest_path}
      {:error, _} = error -> error
    end
  end

  defp release_details(opts) do
    case HTTPClient.get(opts.url, headers: opts.headers, progress?: false) do
      {:ok, data} ->
        Jason.decode(data)

      {:error, "Status 404 Not Found"} ->
        invalid_token? = is_nil(opts.token) or opts.token == ""

        msg =
          if not opts.public? and invalid_token? do
            """
            Missing token

                 For private releases, you must authenticate the request to fetch release assets.
                 You can do this in a few ways:

                   * export or set GITEA_TOKEN=<your-token>
                   * set `token: <get-token-function>` for this Gitea repository in your Nerves system mix.exs
            """
          else
            "No release"
          end

        {:error, msg}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
