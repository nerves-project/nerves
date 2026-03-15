# SPDX-FileCopyrightText: 2023 Jon Carstens
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Artifact.Resolvers.GithubAPITest do
  use ExUnit.Case, async: true
  use Mimic

  alias Nerves.Artifact.Resolvers.GithubAPI
  alias Nerves.Utils.HTTPClient

  setup do
    %{
      repo: "nerves-project/nerves_system_rpi4",
      opts: [
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

    assert GithubAPI.get({context.repo, opts}) == {:error, "No release"}
  end

  test "private release not found", context do
    HTTPClient |> expect(:get, fn _url, _opts -> {:error, "Status 404 Not Found"} end)

    assert GithubAPI.get({context.repo, context.opts}) == {:error, "No release"}
  end

  test "private release fails without token", context do
    HTTPClient |> expect(:get, fn _url, _opts -> {:error, "Status 404 Not Found"} end)

    opts = Keyword.delete(context.opts, :token)

    assert {:error, msg} = GithubAPI.get({context.repo, opts})

    assert msg == """
           Missing token

                For private releases, you must authenticate the request to fetch release assets.
                You can do this in a few ways:

                  * export or set GITHUB_TOKEN=<your-token>
                  * set `token: <get-token-function>` for this GitHub repository in your Nerves system mix.exs
           """
  end

  test "private release fails with nil token", context do
    HTTPClient |> expect(:get, fn _url, _opts -> {:error, "Status 404 Not Found"} end)

    opts = Keyword.put(context.opts, :token, nil)

    assert {:error, msg} = GithubAPI.get({context.repo, opts})

    assert msg == """
           Missing token

                For private releases, you must authenticate the request to fetch release assets.
                You can do this in a few ways:

                  * export or set GITHUB_TOKEN=<your-token>
                  * set `token: <get-token-function>` for this GitHub repository in your Nerves system mix.exs
           """
  end

  test "mismatched checksum", context do
    details = Jason.encode!(%{assets: [%{name: "howdy.tar.xz"}]})
    HTTPClient |> expect(:get, fn _url, _opts -> {:ok, details} end)

    assert {:error, msg} = GithubAPI.get({context.repo, context.opts})

    assert msg == [
             "No artifact with valid checksum\n\n     Found:\n",
             [["       * ", "howdy.tar.xz", "\n"]]
           ]
  end

  test "no artifacts in release", context do
    no_artifacts = Jason.encode!(%{assets: []})
    HTTPClient |> expect(:get, fn _url, _opts -> {:ok, no_artifacts} end)

    assert {:error, "No release artifacts"} = GithubAPI.get({context.repo, context.opts})
  end

  test "valid artifact", context do
    artifact_url = "http://example.com"

    details =
      Jason.encode!(%{assets: [%{name: context.opts[:artifact_name], url: artifact_url}]})

    expected_details_url =
      "https://api.github.com/repos/#{context.repo}/releases/tags/#{context.opts[:tag]}"

    HTTPClient
    |> expect(:get, fn url, _opts ->
      assert url == expected_details_url
      {:ok, details}
    end)
    |> expect(:get, fn url, _opts ->
      assert url == artifact_url
      {:ok, "artifact data!"}
    end)

    assert {:ok, "artifact data!"} = GithubAPI.get({context.repo, context.opts})
  end

  test "GITHUB_TOKEN takes precedence", context do
    env_token = "look-at-me!"
    gh_token = "dont-look-at-me!"
    refute context.opts[:token] == env_token
    refute context.opts[:token] == gh_token

    HTTPClient
    |> expect(:get, fn _url, opts ->
      [{"Authorization", "Basic " <> encoded}] = opts[:headers]
      [_, req_token] = String.split(Base.decode64!(encoded), ":")
      assert req_token == env_token
      :ok
    end)

    System.put_env("GITHUB_TOKEN", env_token)
    System.put_env("GH_TOKEN", gh_token)
    _ = GithubAPI.get({context.repo, context.opts})
    System.delete_env("GITHUB_TOKEN")
    System.delete_env("GH_TOKEN")
  end

  test "supports GH_TOKEN shorthand", context do
    env_token = "look-at-me!"
    refute context.opts[:token] == env_token

    HTTPClient
    |> expect(:get, fn _url, opts ->
      # A bit hacky since you need to know the internals, but this
      # breaks apart the Authorization header that was created with
      # the token given to the request and confirms it is the one
      # we wanted
      [{"Authorization", "Basic " <> encoded}] = opts[:headers]
      [_, req_token] = String.split(Base.decode64!(encoded), ":")
      assert req_token == env_token
      :ok
    end)

    System.put_env("GH_TOKEN", env_token)
    _ = GithubAPI.get({context.repo, context.opts})
    System.delete_env("GH_TOKEN")
  end

  test "public release uses public download when API rate limit reached", context do
    expected_details_url =
      "https://api.github.com/repos/#{context.repo}/releases/tags/#{context.opts[:tag]}"

    opts =
      context.opts
      |> Keyword.put(:public?, true)
      |> Keyword.delete(:token)

    expected_public_download_url =
      "https://github.com/#{context.repo}/releases/download/#{opts[:tag]}/#{opts[:artifact_name]}"

    HTTPClient
    |> expect(:get, fn url, _opts ->
      assert url == expected_details_url
      {:error, "Status 403 rate limit exceeded"}
    end)
    |> expect(:get, fn url, _opts ->
      assert url == expected_public_download_url
      {:ok, "artifact data!"}
    end)

    assert {:ok, "artifact data!"} = GithubAPI.get({context.repo, opts})
  end

  test "private release fails when API rate limit reached", context do
    HTTPClient |> expect(:get, fn _url, _opts -> {:error, "Status 403 rate limit exceeded"} end)

    assert {:error, "Status 403 rate limit exceeded"} =
             GithubAPI.get({context.repo, context.opts})
  end
end
