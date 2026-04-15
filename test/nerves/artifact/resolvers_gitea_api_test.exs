# SPDX-FileCopyrightText: 2023 James Harton
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Artifact.Resolvers.GiteaAPITest do
  use ExUnit.Case
  use Mimic

  alias Nerves.Artifact.Resolvers.GiteaAPI
  alias Nerves.Utils.HTTPClient

  # These are just markers for easier debug. Files should never be created since the HTTP downloader is mocked.
  @invalid_download_path "/should_not_work.tgz"
  @good_download_path "good_path.tar.gz"

  @org_repo "jmshrtn/nerves_artifact_test"
  @artifact_filename "nerves_system_rpi-portable-1.0.0-1234567.tar.gz"
  @version "1.0.0"
  @release_tag "v1.0.0"
  @base_url "https://gitea.com/"
  @release_api_url "https://gitea.com/api/v1/repos/#{@org_repo}/releases/tags/#{@release_tag}"
  @release_download_url "#{@base_url}#{@org_repo}/releases/download/#{@release_tag}/#{@artifact_filename}"

  setup do
    # Clean up any environment settings that affect tests. This should never
    # be specified by the user for any testing so there's no need to save and
    # restore the values.
    System.delete_env("GITEA_TOKEN")
    :ok
  end

  defp plan(opts \\ []) do
    {site, opts} = Keyword.pop(opts, :site, :gitea_releases)

    case site do
      :gitea_releases ->
        uri = "#{@base_url}#{@org_repo}"

        {GiteaAPI, prepared} =
          GiteaAPI.plan({:gitea_releases, uri, opts}, @version, @artifact_filename)

        prepared

      :gitea_api ->
        opts = Keyword.put_new(opts, :base_url, @base_url)

        {GiteaAPI, prepared} =
          GiteaAPI.plan({:gitea_api, @org_repo, opts}, @version, @artifact_filename)

        prepared
    end
  end

  defp release_json(assets \\ nil) do
    assets =
      assets ||
        [%{"name" => @artifact_filename, "browser_download_url" => @release_download_url}]

    %{"tag_name" => @release_tag, "assets" => assets}
  end

  test "public release not found" do
    prepared = plan()

    HTTPClient
    |> expect(:download, fn _url, _path, _opts -> {:error, "Status 404 Not Found"} end)

    assert {:error, msg} = GiteaAPI.get(prepared, @invalid_download_path)
    assert msg =~ "Download failed"
    assert msg =~ "#{@org_repo}/releases/tag/#{@release_tag}"
  end

  test "private release not found" do
    prepared = plan(token: "1234")

    HTTPClient
    |> expect(:download, fn _url, _path, _opts -> {:error, "Status 404 Not Found"} end)

    assert {:error, msg} = GiteaAPI.get(prepared, @invalid_download_path)
    assert msg =~ "Download failed"
    assert msg =~ "#{@org_repo}/releases/tag/#{@release_tag}"
  end

  test "private release fails without token" do
    prepared = %GiteaAPI{
      org_repo_url: URI.parse("#{@base_url}/#{@org_repo}"),
      auth_token: nil,
      artifact_filename: @artifact_filename,
      tag: @release_tag,
      method: :gitea_release
    }

    HTTPClient
    |> expect(:download, fn _url, _path, _opts -> {:error, "Status 404 Not Found"} end)

    assert {:error, msg} = GiteaAPI.get(prepared, @invalid_download_path)
    assert msg =~ "Download failed"
    assert msg =~ "GITEA_TOKEN"
    assert msg =~ "#{@org_repo}/releases/tag/#{@release_tag}"
  end

  test "private release fails with nil token" do
    prepared = %GiteaAPI{
      org_repo_url: URI.parse("#{@base_url}/#{@org_repo}"),
      auth_token: nil,
      artifact_filename: @artifact_filename,
      tag: @release_tag,
      method: :gitea_release
    }

    HTTPClient
    |> expect(:download, fn _url, _path, _opts -> {:error, "Status 404 Not Found"} end)

    assert {:error, msg} = GiteaAPI.get(prepared, @invalid_download_path)
    assert msg =~ "Download failed"
    assert msg =~ "#{@org_repo}/releases/tag/#{@release_tag}"
  end

  test "mismatched checksum" do
    prepared = plan(site: :gitea_api, token: "1234")

    HTTPClient
    |> expect(:get_json, fn _url, _opts ->
      {:ok,
       release_json([
         %{
           "name" => "wrong_filename.tar.gz",
           "browser_download_url" => "https://example.com/wrong.tar.gz"
         }
       ])}
    end)

    assert {:error, msg} = GiteaAPI.get(prepared, @invalid_download_path)
    assert msg =~ "Asset '#{@artifact_filename}' not found in release"
  end

  test "no artifacts in release" do
    prepared = plan(site: :gitea_api, token: "1234")

    HTTPClient
    |> expect(:get_json, fn _url, _opts ->
      {:ok, release_json([])}
    end)

    assert {:error, msg} = GiteaAPI.get(prepared, @invalid_download_path)
    assert msg =~ "Asset '#{@artifact_filename}' not found in release"
  end

  test "valid artifact" do
    prepared = plan(token: "1234")

    expected_url =
      URI.parse(
        "#{@base_url}#{@org_repo}/releases/download/#{@release_tag}/#{@artifact_filename}"
      )

    HTTPClient
    |> expect(:download, 1, fn url, path, opts ->
      assert url == expected_url
      assert path == @good_download_path
      assert [{"Authorization", "token 1234"}] = opts[:headers]
      :ok
    end)

    assert :ok = GiteaAPI.get(prepared, @good_download_path)
  end

  test "GITEA_TOKEN takes precedence" do
    env_token = "look-at-me!"

    System.put_env("GITEA_TOKEN", env_token)

    prepared = plan(token: "dont-look-at-me!")

    HTTPClient
    |> expect(:download, 1, fn _url, _path, opts ->
      assert [{"Authorization", "token " <> ^env_token}] = opts[:headers]
      :ok
    end)

    assert :ok = GiteaAPI.get(prepared, @good_download_path)
  end

  test "gitea_release with token uses direct download" do
    prepared = plan(token: "1234")

    expected_url =
      URI.parse(
        "#{@base_url}#{@org_repo}/releases/download/#{@release_tag}/#{@artifact_filename}"
      )

    HTTPClient
    |> stub(:get_json, fn _, _ -> flunk("get_json should not be called for :gitea_release") end)
    |> expect(:download, fn url, _path, opts ->
      assert url == expected_url
      assert [{"Authorization", "token 1234"}] = opts[:headers]
      :ok
    end)

    assert :ok = GiteaAPI.get(prepared, @good_download_path)
  end

  test "gitea_api uses API to find asset" do
    prepared = plan(site: :gitea_api, token: "1234")

    HTTPClient
    |> expect(:get_json, fn url, opts ->
      assert URI.to_string(url) == @release_api_url
      assert [{"Authorization", "token 1234"}] = opts[:headers]
      {:ok, release_json()}
    end)
    |> expect(:download, fn url, _path, opts ->
      assert url == @release_download_url
      assert [{"Authorization", "token 1234"}] = opts[:headers]
      :ok
    end)

    assert :ok = GiteaAPI.get(prepared, @good_download_path)
  end
end
