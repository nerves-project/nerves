# SPDX-FileCopyrightText: 2023 James Harton
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Artifact.Downloaders.GiteaAPITest do
  use ExUnit.Case
  use Mimic

  alias Nerves.Artifact.Downloaders.GiteaAPI
  alias Nerves.Utils.HTTPClient

  # These are just markers for easier debug. Files should never be created since the HTTP downloader is mocked.
  @invalid_download_path "/should_not_work.tgz"
  @good_download_path "good_path.tar.gz"

  @no_artifacts_response Jason.encode!(%{assets: []})

  setup do
    # Clean up any environment settings that affect tests. This should never
    # be specified by the user for any testing so there's no need to save and
    # restore the values.
    System.delete_env("GITEA_TOKEN")

    %{
      repo: "jmshrtn/nerves_artifact_test",
      opts: [
        base_url: "https://gitea.com",
        artifact_name: "nerves_system_rpi-portable-1.0.0-1234567.tar.gz",
        tag: "v1.0.0",
        token: "1234"
      ]
    }
  end

  test "public release not found", context do
    HTTPClient |> expect(:get, fn _url, _opts -> {:error, "Status 404 Not Found"} end)

    opts =
      context.opts
      |> Keyword.put(:public?, true)
      |> Keyword.delete(:token)

    assert GiteaAPI.download({context.repo, opts}, @invalid_download_path) == {:error, "No release"}
  end

  test "private release not found", context do
    HTTPClient |> expect(:get, fn _url, _opts -> {:error, "Status 404 Not Found"} end)

    assert GiteaAPI.download({context.repo, context.opts}, @invalid_download_path) ==
             {:error, "No release"}
  end

  test "private release fails without token", context do
    HTTPClient |> expect(:get, fn _url, _opts -> {:error, "Status 404 Not Found"} end)

    opts = Keyword.delete(context.opts, :token)

    assert {:error, msg} = GiteaAPI.download({context.repo, opts}, @invalid_download_path)

    assert msg == """
           Missing token

                For private releases, you must authenticate the request to fetch release assets.
                You can do this in a few ways:

                  * export or set GITEA_TOKEN=<your-token>
                  * set `token: <get-token-function>` for this Gitea repository in your Nerves system mix.exs
           """
  end

  test "private release fails with nil token", context do
    HTTPClient |> expect(:get, fn _url, _opts -> {:error, "Status 404 Not Found"} end)

    opts = Keyword.put(context.opts, :token, nil)

    assert {:error, msg} = GiteaAPI.download({context.repo, opts}, @invalid_download_path)

    assert msg == """
           Missing token

                For private releases, you must authenticate the request to fetch release assets.
                You can do this in a few ways:

                  * export or set GITEA_TOKEN=<your-token>
                  * set `token: <get-token-function>` for this Gitea repository in your Nerves system mix.exs
           """
  end

  test "mismatched checksum", context do
    details = Jason.encode!(%{assets: [%{name: "howdy.tar.xz"}]})
    HTTPClient |> expect(:get, fn _url, _opts -> {:ok, details} end)
    reject(&HTTPClient.download/3)

    assert {:error, msg} = GiteaAPI.download({context.repo, context.opts}, @invalid_download_path)

    assert msg == [
             "No artifact with valid checksum\n\n     Found:\n",
             [["       * ", "howdy.tar.xz", "\n"]]
           ]
  end

  test "no artifacts in release", context do
    HTTPClient |> expect(:get, fn _url, _opts -> {:ok, @no_artifacts_response} end)
    reject(&HTTPClient.download/3)

    assert {:error, "No release artifacts"} =
             GiteaAPI.download({context.repo, context.opts}, @invalid_download_path)
  end

  test "valid artifact", context do
    artifact_url = "http://example.com"

    details =
      Jason.encode!(%{
        assets: [%{name: context.opts[:artifact_name], browser_download_url: artifact_url}]
      })

    expected_details_url =
      "https://gitea.com/api/v1/repos/#{context.repo}/releases/tags/#{context.opts[:tag]}"

    HTTPClient
    |> expect(:get, fn url, _opts ->
      assert url == expected_details_url
      {:ok, details}
    end)
    |> expect(:download, 1, fn url, path, _opts ->
      assert url == artifact_url
      assert path == @good_download_path
      :ok
    end)

    assert :ok = GiteaAPI.download({context.repo, context.opts}, @good_download_path)
  end

  test "GITEA_TOKEN takes precedence", context do
    env_token = "look-at-me!"
    gitea_token = "dont-look-at-me!"
    refute context.opts[:token] == env_token
    refute context.opts[:token] == gitea_token

    HTTPClient
    |> expect(:get, fn _url, opts ->
      [{"Authorization", "token " <> req_token}] = opts[:headers]
      assert req_token == env_token
      {:ok, @no_artifacts_response}
    end)

    System.put_env("GITEA_TOKEN", env_token)

    {:error, "No release artifacts"} =
      GiteaAPI.download({context.repo, context.opts}, @invalid_download_path)

    System.delete_env("GITEA_TOKEN")
  end
end
