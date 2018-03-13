defmodule Nerves.Artifact.Resolvers.GithubAPI do
  @behaviour Nerves.Artifact.Resolver

  @base_url "https://api.github.com/"

  alias Nerves.Utils
  alias Nerves.Utils.HTTPClient

  def get({org_proj, opts}) do
    artifact_name = opts[:artifact_name]

    {:ok, http_pid} = HTTPClient.start_link()
    token = get_token(opts, artifact_name)
    username = get_username(opts, artifact_name)
    tag = get_tag(opts, artifact_name)

    credentials = Base.encode64(username <> ":" <> token)
    auth_header = {"Authorization", "Basic " <> credentials}
    accept_header = {"Accept", "application/octet-stream"}
    base_url = opts[:base_url] || @base_url

    url = Path.join([base_url, "repos", org_proj, "releases", "tags", tag])

    Nerves.Utils.Shell.info("  Downloading artifacts from #{url}")

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

  defp get_username(opts, artifact_name) do
    case Keyword.get(opts, :username) do
      nil ->
        Mix.raise("""
        GitHub username not set for artifact: #{artifact_name}.

        Ensure that you have your GitHub username set correctly
        in your environment. You might need to export an environmental
        variable.

        For example:

        export GITHUB_USER=<your_username>

        For correctly setting up your environment please see the documentation for the artifact you are
        trying to download.
        """)

      username ->
        username
    end
  end

  defp get_token(opts, artifact_name) do
    case Keyword.get(opts, :token) do
      nil ->
        Mix.raise("""
        GitHub token not set for artifact: #{artifact_name}

        Ensure that you have your GitHub token set correctly
        in your environment. You might need to export an environmental
        variable.

        For example:

        export GITHUB_TOKEN=<your_token>

        For correctly setting up your environment please see the documentation for the artifact you are
        trying to download.
        """)

      token ->
        token
    end
  end

  defp get_tag(opts, artifact_name) do
    case Keword.get(opts, :tag) do
      nil ->
        Mix.raise("""
        GitHub release tag not set for artifact: #{artifact_name}.

        Ensure that you have set the tag field in the artifact sites
        configuration for this artifact.

        For example:
          {:github_api, "github_org/my_custom_system", username: System.get_env("GITHUB_USER"), token: System.get_env("GITHUB_TOKEN"), tag: @version}
        """)

      tag ->
        tag
    end
  end
end
