defmodule Nerves.Artifact.Resolvers.GithubAPI do
  @moduledoc false
  @behaviour Nerves.Artifact.Resolver

  alias Nerves.Utils.{HTTPClient, Shell}

  @base_url "https://api.github.com/"

  defstruct artifact_name: nil,
            base_url: @base_url,
            headers: [],
            http_client: HTTPClient,
            http_pid: nil,
            public?: false,
            opts: [],
            repo: nil,
            tag: "",
            token: "",
            url: nil,
            username: ""

  @impl Nerves.Artifact.Resolver
  def get({org_proj, opts}) do
    opts =
      %{struct(__MODULE__, opts) | opts: opts, repo: org_proj}
      |> maybe_adjust_token()
      |> add_http_opts()
      |> maybe_start_http()

    result = fetch_artifact(opts)

    opts.http_client.stop(opts.http_pid)

    result
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

  defp maybe_start_http(%{http_pid: pid} = opts) when is_pid(pid), do: opts

  defp maybe_start_http(opts) do
    {:ok, http_pid} = opts.http_client.start_link()
    %{opts | http_pid: http_pid}
  end

  defp fetch_artifact(opts) do
    info = if System.get_env("NERVES_DEBUG") == "1", do: opts.url, else: opts.artifact_name

    Shell.info(["  [GitHub] ", info])

    with {:ok, assets_or_url} <- release_details(opts),
         {:ok, asset_url} <- get_asset_url(assets_or_url, opts) do
      opts.http_client.get(opts.http_pid, asset_url,
        headers: [{"Accept", "application/octet-stream"} | opts.headers]
      )
    end
  end

  defp release_details(opts) do
    case opts.http_client.get(opts.http_pid, opts.url, headers: opts.headers, progress?: false) do
      {:ok, data} ->
        Jason.decode(data)

      {:error, "Status 403 rate limit exceeded"} when opts.public? ->
        # Apparently this user has made too many public API requests from their IP
        # so let's just fallback to the old way of fetching via a release download.
        # If the release doesn't exist, we won't be able help provide hints about
        # a checksum mismatch or bad name, but the tradeoff is worth it if the
        # release actually does exist
        {:ok,
         "https://github.com/#{opts.repo}/releases/download/#{opts.tag}/#{opts.artifact_name}"}

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

      result ->
        result
    end
  end

  defp get_asset_url(url, _) when is_binary(url), do: {:ok, url}

  defp get_asset_url(%{"assets" => []}, _opts) do
    {:error, "No release artifacts"}
  end

  defp get_asset_url(%{"assets" => assets}, %{artifact_name: artifact_name}) do
    ret =
      Enum.find(assets, fn %{"name" => name} ->
        String.equivalent?(artifact_name, name)
      end)

    case ret do
      nil ->
        available = for %{"name" => name} <- assets, do: ["       * ", name, "\n"]
        msg = ["No artifact with valid checksum\n\n     Found:\n", available]

        {:error, msg}

      %{"url" => url} ->
        {:ok, url}
    end
  end
end
