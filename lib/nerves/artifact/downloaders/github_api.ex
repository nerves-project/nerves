# SPDX-FileCopyrightText: 2018 Justin Schneck
# SPDX-FileCopyrightText: 2018 Matt Ludwigs
# SPDX-FileCopyrightText: 2022 Frank Hunleth
# SPDX-FileCopyrightText: 2023 Jon Carstens
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Artifact.Downloaders.GithubAPI do
  @moduledoc false
  @behaviour Nerves.Artifact.Downloader

  alias Nerves.Utils.HTTPClient
  alias Nerves.Utils.Shell

  @base_url "https://api.github.com/"

  defstruct dest_dir: nil,
            download_names: [],
            base_url: @base_url,
            headers: [],
            public?: false,
            opts: [],
            repo: nil,
            tag: "",
            token: "",
            url: nil,
            username: ""

  @impl Nerves.Artifact.Downloader
  def expand_site({:github_releases, org_proj}, info) do
    opts = [
      public?: true,
      tag: "v#{info[:version]}"
    ]

    {:ok, {org_proj, opts}}
  end

  def expand_site({:github_api, org_proj, resolver_opts}, _info) do
    {:ok, {org_proj, resolver_opts}}
  end

  def expand_site(_site_config, _info), do: :skip

  @impl Nerves.Artifact.Downloader
  def download(org_proj, opts) do
    s =
      %{struct(__MODULE__, opts) | opts: opts, repo: org_proj}
      |> maybe_adjust_token()
      |> add_http_opts()

    fetch_artifact(s)
  end

  @impl Nerves.Artifact.Downloader
  def site_help() do
    [
      ~s({:github_releases, "owner/repo"}),
      ~s({:github_api, "owner/repo", username: "skroob", token: "1234567", tag: "v0.1.0"})
    ]
  end

  defp add_http_opts(opts) do
    headers =
      if opts.public? do
        []
      else
        # make safe values here in case nil was supplied as an option
        # The request will fail and error will be reported later on
        user = opts.username || ""
        token = opts.token || ""

        credentials = Base.encode64(user <> ":" <> token)
        [{"Authorization", "Basic " <> credentials}]
      end

    %{
      opts
      | headers: headers,
        url: Path.join([opts.base_url, "repos", opts.repo, "releases", "tags", opts.tag])
    }
  end

  defp maybe_adjust_token(opts) do
    token = System.get_env("GITHUB_TOKEN") || System.get_env("GH_TOKEN")

    if token do
      # Let the env var take precedence
      %{opts | token: token}
    else
      opts
    end
  end

  defp fetch_artifact(opts) do
    info = if System.get_env("NERVES_DEBUG") == "1", do: opts.url, else: hd(opts.download_names)

    Shell.info(["  [GitHub] ", info])

    case release_details(opts) do
      {:ok, {:fallback_url, name, url}} ->
        do_download(url, name, opts)

      {:ok, %{"assets" => assets}} ->
        download_from_assets(assets, opts)

      {:error, _} = error ->
        error
    end
  end

  defp download_from_assets([], _opts), do: {:error, "No release artifacts"}

  defp download_from_assets(assets, opts) do
    case find_matching_asset(assets, opts.download_names) do
      {%{"url" => url}, name} ->
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

      {:error, "Status 403 rate limit exceeded"} when opts.public? ->
        # Apparently this user has made too many public API requests from their IP
        # so let's just fallback to the old way of fetching via a release download.
        # If the release doesn't exist, we won't be able help provide hints about
        # a checksum mismatch or bad name, but the tradeoff is worth it if the
        # release actually does exist
        name = hd(opts.download_names)

        {:ok,
         {:fallback_url, name,
          "https://github.com/#{opts.repo}/releases/download/#{opts.tag}/#{name}"}}

      {:error, "Status 404 Not Found"} ->
        invalid_token? = is_nil(opts.token) or opts.token == ""

        msg =
          if not opts.public? and invalid_token? do
            """
            Missing token

                 For private releases, you must authenticate the request to fetch release assets.
                 You can do this in a few ways:

                   * export or set GITHUB_TOKEN=<your-token>
                   * set `token: <get-token-function>` for this GitHub repository in your Nerves system mix.exs
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
