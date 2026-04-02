# SPDX-FileCopyrightText: 2023 Jon Carstens
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Artifact.Downloaders.GithubAPITest do
  use ExUnit.Case, async: true
  use Mimic

  alias Nerves.Artifact.Downloaders.GithubAPI
  alias Nerves.Utils.HTTPClient

  @download_name "nerves_system_rpi-portable-1.0.0-1234567"
  @download_names [@download_name <> ".tar.gz", @download_name <> ".tar.xz"]

  @no_artifacts_response Jason.encode!(%{assets: []})

  setup do
    # Clean up any environment settings that affect tests. These should never
    # be specified by the user for any testing so there's no need to save and
    # restore their values.
    System.delete_env("GITHUB_TOKEN")
    System.delete_env("GH_TOKEN")

    %{
      repo: "nerves-project/nerves_system_rpi4",
      opts: [
        dest_dir: "/tmp/test",
        download_names: @download_names,
        tag: "v1.0.0",
        token: "1234"
      ]
    }
  end

  test "public release not found", context do
    HTTPClient |> expect(:get, fn _url, _opts -> {:error, "Status 404 Not Found"} end)
    reject(&HTTPClient.download/3)

    opts =
      context.opts
      |> Keyword.put(:public?, true)
      |> Keyword.delete(:token)

    assert GithubAPI.download(context.repo, opts) == {:error, "No release"}
  end

  test "private release not found", context do
    HTTPClient |> expect(:get, fn _url, _opts -> {:error, "Status 404 Not Found"} end)
    reject(&HTTPClient.download/3)

    assert GithubAPI.download(context.repo, context.opts) == {:error, "No release"}
  end

  test "private release fails without token", context do
    HTTPClient |> expect(:get, fn _url, _opts -> {:error, "Status 404 Not Found"} end)
    reject(&HTTPClient.download/3)

    opts = Keyword.delete(context.opts, :token)

    assert {:error, msg} = GithubAPI.download(context.repo, opts)

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
    reject(&HTTPClient.download/3)

    opts = Keyword.put(context.opts, :token, nil)

    assert {:error, msg} = GithubAPI.download(context.repo, opts)

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
    reject(&HTTPClient.download/3)

    assert {:error, msg} = GithubAPI.download(context.repo, context.opts)

    assert msg == [
             "No artifact with valid checksum\n\n     Found:\n",
             [["       * ", "howdy.tar.xz", "\n"]]
           ]
  end

  test "no artifacts in release", context do
    HTTPClient |> expect(:get, fn _url, _opts -> {:ok, @no_artifacts_response} end)
    reject(&HTTPClient.download/3)

    assert {:error, "No release artifacts"} = GithubAPI.download(context.repo, context.opts)
  end

  test "valid artifact", context do
    artifact_url = "http://example.com"
    artifact_name = @download_name <> ".tar.gz"

    details =
      Jason.encode!(%{assets: [%{name: artifact_name, url: artifact_url}]})

    expected_details_url =
      "https://api.github.com/repos/#{context.repo}/releases/tags/#{context.opts[:tag]}"

    expected_dest = Path.join(context.opts[:dest_dir], artifact_name)

    HTTPClient
    |> expect(:get, fn url, _opts ->
      assert url == expected_details_url
      {:ok, details}
    end)
    |> expect(:download, fn url, dest_path, _opts ->
      assert url == artifact_url
      assert dest_path == expected_dest
      :ok
    end)

    assert {:ok, ^expected_dest} = GithubAPI.download(context.repo, context.opts)
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
      {:ok, @no_artifacts_response}
    end)

    reject(&HTTPClient.download/3)

    System.put_env("GITHUB_TOKEN", env_token)
    System.put_env("GH_TOKEN", gh_token)
    _ = GithubAPI.download(context.repo, context.opts)
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
      {:error, "test complete"}
    end)

    reject(&HTTPClient.download/3)

    System.put_env("GH_TOKEN", env_token)
    _ = GithubAPI.download(context.repo, context.opts)
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
      "https://github.com/#{context.repo}/releases/download/#{opts[:tag]}/#{@download_name}.tar.gz"

    expected_dest = Path.join(opts[:dest_dir], @download_name <> ".tar.gz")

    HTTPClient
    |> expect(:get, fn url, _opts ->
      assert url == expected_details_url
      {:error, "Status 403 rate limit exceeded"}
    end)
    |> expect(:download, fn url, dest_path, _opts ->
      assert url == expected_public_download_url
      assert dest_path == expected_dest
      :ok
    end)

    assert {:ok, ^expected_dest} = GithubAPI.download(context.repo, opts)
  end

  test "private release fails when API rate limit reached", context do
    HTTPClient |> expect(:get, fn _url, _opts -> {:error, "Status 403 rate limit exceeded"} end)
    reject(&HTTPClient.download/3)

    assert {:error, "Status 403 rate limit exceeded"} =
             GithubAPI.download(context.repo, context.opts)
  end
end
