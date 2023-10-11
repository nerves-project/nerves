defmodule Nerves.Artifact.Resolvers.GiteaAPITest do
  use ExUnit.Case, async: true

  alias Nerves.Artifact.Resolvers.GiteaAPI

  setup do
    %{
      repo: "jmshrtn/nerves_artifact_test",
      opts: [
        base_url: "https://gitea.com",
        artifact_name: "nerves_system_rpi-portable-1.0.0-1234567.tar.gz",
        http_client: NervesTest.HTTPClient,
        tag: "v1.0.0",
        token: "1234"
      ]
    }
  end

  test "public release not found", context do
    context = start_http_client!(context, [{:error, "Status 404 Not Found"}])

    opts =
      context.opts
      |> Keyword.put(:public?, true)
      |> Keyword.delete(:token)

    assert GiteaAPI.get({context.repo, opts}) == {:error, "No release"}
  end

  test "private release not found", context do
    context = start_http_client!(context, [{:error, "Status 404 Not Found"}])

    assert GiteaAPI.get({context.repo, context.opts}) == {:error, "No release"}
  end

  test "private release fails without token", context do
    context = start_http_client!(context, [{:error, "Status 404 Not Found"}])

    opts = Keyword.delete(context.opts, :token)

    assert {:error, msg} = GiteaAPI.get({context.repo, opts})

    assert msg == """
           Missing token

                For private releases, you must authenticate the request to fetch release assets.
                You can do this in a few ways:

                  * export or set GITEA_TOKEN=<your-token>
                  * set `token: <get-token-function>` for this Gitea repository in your Nerves system mix.exs
           """
  end

  test "private release fails with nil token", context do
    context = start_http_client!(context, [{:error, "Status 404 Not Found"}])

    opts = Keyword.put(context.opts, :token, nil)

    assert {:error, msg} = GiteaAPI.get({context.repo, opts})

    assert msg == """
           Missing token

                For private releases, you must authenticate the request to fetch release assets.
                You can do this in a few ways:

                  * export or set GITEA_TOKEN=<your-token>
                  * set `token: <get-token-function>` for this Gitea repository in your Nerves system mix.exs
           """
  end

  test "mismatched checksum", context do
    details = {:ok, Jason.encode!(%{assets: [%{name: "howdy.tar.xz"}]})}
    context = start_http_client!(context, [details])

    assert {:error, msg} = GiteaAPI.get({context.repo, context.opts})

    assert msg == [
             "No artifact with valid checksum\n\n     Found:\n",
             [["       * ", "howdy.tar.xz", "\n"]]
           ]
  end

  test "no artifacts in release", context do
    no_artifacts = {:ok, Jason.encode!(%{assets: []})}
    context = start_http_client!(context, [no_artifacts])

    assert {:error, "No release artifacts"} = GiteaAPI.get({context.repo, context.opts})
  end

  test "valid artifact", context do
    artifact_url = "http://example.com"

    details =
      {:ok,
       Jason.encode!(%{
         assets: [%{name: context.opts[:artifact_name], browser_download_url: artifact_url}]
       })}

    data = {:ok, "artifact data!"}
    context = start_http_client!(context, [details, data], self())

    assert ^data = GiteaAPI.get({context.repo, context.opts})

    # Requests the GiteaAPI for release details first
    expected_details_url =
      "https://gitea.com/api/v1/repos/#{context.repo}/releases/tags/#{context.opts[:tag]}"

    assert_receive {:get, ^expected_details_url, _opts}

    # Uses the URL for the artifact provided by Gitea to download
    assert_receive {:get, ^artifact_url, _opts}
  end

  test "GITEA_TOKEN takes precedence", context do
    env_token = "look-at-me!"
    gitea_token = "dont-look-at-me!"
    refute context.opts[:token] == env_token
    refute context.opts[:token] == gitea_token
    context = start_http_client!(context, [], self())

    System.put_env("GITEA_TOKEN", env_token)
    _ = GiteaAPI.get({context.repo, context.opts})
    System.delete_env("GITEA_TOKEN")

    assert_receive {:get, _url, opts}

    # A bit hacky since you need to know the internals, but this
    # breaks apart the Authorization header that was created with
    # the token given to the request and confirms it is the one
    # we wanted
    [{"Authorization", "token " <> req_token}] = opts[:headers]

    assert env_token == req_token
  end

  defp start_http_client!(context, returns, echo \\ nil) do
    client = context.opts[:http_client]
    opts = [name: context.test, returns: returns, echo: echo]
    http_pid = start_supervised!({client, opts})
    put_in(context, [:opts, :http_pid], http_pid)
  end
end
