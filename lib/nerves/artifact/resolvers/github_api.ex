defmodule Nerves.Artifact.Resolvers.GithubAPI do
  @behaviour Nerves.Artifact.Resolver

  @base_url "https://api.github.com/"

  alias Nerves.Utils
  alias Nerves.Utils.HTTPClient

  def get({org_proj, opts}) do
    artifact_name = opts[:artifact_name]

    {:ok, http_pid} = HTTPClient.start_link()
    token = opts[:token]
    username = opts[:username]
    tag = opts[:tag]

    credentials = Base.encode64(username <> ":" <> token)
    auth_header = {"Authorization", "Basic " <> credentials}
    accept_header = {"Accept", "application/octet-stream"}
    base_url = opts[:base_url] || @base_url

    url = Path.join([base_url, "repos", org_proj, "releases", "tags", tag])

    result =
      with {:ok, data} <- HTTPClient.get(http_pid, url, headers: [auth_header], progress?: false),
           %{"assets" => assets} <- Utils.json_decode(data),
           {:ok, url} <- get_asset_url(assets, artifact_name),
           {:ok, data} <- HTTPClient.get(http_pid, url, headers: [auth_header, accept_header]) do
        {:ok, data}
      end

    Nerves.Utils.HTTPClient.stop(http_pid)
    result
  end

  defp get_asset_url(assets, artifact_name) do
    ret =
      Enum.find(assets, fn %{"name" => name} ->
        String.equivalent?(artifact_name, name)
      end)

    case ret do
      nil -> {:error, "No artifact found"}
      %{"url" => url} -> {:ok, url}
    end
  end
end
