# SPDX-FileCopyrightText: 2023 Jon Carstens
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Artifact.Resolvers.GithubAPITest do
  use ExUnit.Case
  use Mimic

  alias Nerves.Artifact.Resolvers.GithubAPI
  alias Nerves.Utils.HTTPClient

  # These are just markers for easier debug. Files should never be created since the HTTP downloader is mocked.
  @invalid_download_path "/should_not_work.tgz"
  @good_download_path "good_path.tar.gz"

  @org_repo "nerves-project/nerves_system_rpi4"
  @artifact_filename "nerves_system_rpi-portable-1.0.0-1234567.tar.gz"
  @version "1.0.0"
  @release_tag "v1.0.0"

  @release_api_url "https://api.github.com/repos/#{@org_repo}/releases/tags/#{@release_tag}"
  @asset_api_url "https://api.github.com/repos/#{@org_repo}/releases/assets/12345"
  @release_download_url "https://github.com/#{@org_repo}/releases/download/#{@release_tag}/#{@artifact_filename}"

  setup do
    # Clean up any environment settings that affect tests. These should never
    # be specified by the user for any testing so there's no need to save and
    # restore their values.
    System.delete_env("GITHUB_TOKEN")
    System.delete_env("GH_TOKEN")

    :ok
  end

  defp plan(opts \\ []) do
    {site, opts} = Keyword.pop(opts, :method, :github_releases)
    opts = Keyword.put_new(opts, :use_gh_cli?, false)

    {GithubAPI, prepared} =
      GithubAPI.plan({site, @org_repo, opts}, @version, @artifact_filename)

    prepared
  end

  defp release_json(assets \\ nil) do
    assets = assets || [%{"name" => @artifact_filename, "url" => @asset_api_url}]
    %{"tag_name" => @release_tag, "assets" => assets}
  end

  # --- No token: uses direct web URL ---

  test "public release not found" do
    prepared = plan()

    HTTPClient
    |> expect(:download, fn _url, _path, _opts -> {:error, "Status 404 Not Found"} end)

    assert {:error, msg} = GithubAPI.get(prepared, @invalid_download_path)
    assert msg =~ "Download failed"
    assert msg =~ "#{@org_repo}/releases/tag/#{@release_tag}"
  end

  test "private release fails without token" do
    prepared = %GithubAPI{
      github_url: URI.parse("https://github.com"),
      org_repo: @org_repo,
      custom_auth_token: nil,
      artifact_filename: @artifact_filename,
      tag: @release_tag,
      method: :github_release
    }

    HTTPClient
    |> expect(:download, fn _url, _path, _opts -> {:error, "Status 404 Not Found"} end)

    assert {:error, msg} = GithubAPI.get(prepared, @invalid_download_path)
    assert msg =~ "Download failed"
    assert msg =~ "#{@org_repo}/releases/tag/#{@release_tag}"
  end

  test "private release fails with nil token" do
    prepared = %GithubAPI{
      github_url: URI.parse("https://github.com"),
      org_repo: @org_repo,
      custom_auth_token: nil,
      artifact_filename: @artifact_filename,
      tag: @release_tag,
      method: :github_release
    }

    HTTPClient
    |> expect(:download, fn _url, _path, _opts -> {:error, "Status 404 Not Found"} end)

    assert {:error, msg} = GithubAPI.get(prepared, @invalid_download_path)
    assert msg =~ "Download failed"
    assert msg =~ "#{@org_repo}/releases/tag/#{@release_tag}"
  end

  # --- With token: uses GitHub API ---

  test "release API returns 404" do
    prepared = plan(method: :github_api, token: "1234")

    HTTPClient
    |> expect(:get_json, fn url, opts ->
      assert URI.to_string(url) == @release_api_url
      assert {"Authorization", "Bearer 1234"} in opts[:headers]
      {:error, "Status 404 Not Found"}
    end)

    assert {:error, msg} = GithubAPI.get(prepared, @invalid_download_path)
    assert msg =~ "Download failed"
    assert msg =~ "#{@org_repo}/releases/tag/#{@release_tag}"
  end

  test "asset not found in release" do
    prepared = plan(method: :github_api, token: "1234")

    HTTPClient
    |> expect(:get_json, fn _url, _opts ->
      {:ok, release_json([%{"name" => "wrong_filename.tar.gz", "url" => @asset_api_url}])}
    end)

    assert {:error, msg} = GithubAPI.get(prepared, @invalid_download_path)
    assert msg =~ "Asset '#{@artifact_filename}' not found in release"
  end

  test "no artifacts in release" do
    prepared = plan(method: :github_api, token: "1234")

    HTTPClient
    |> expect(:get_json, fn _url, _opts ->
      {:ok, release_json([])}
    end)

    assert {:error, msg} = GithubAPI.get(prepared, @invalid_download_path)
    assert msg =~ "Asset '#{@artifact_filename}' not found in release"
  end

  test "asset download fails" do
    prepared = plan(method: :github_api, token: "1234")

    HTTPClient
    |> expect(:get_json, fn _url, _opts -> {:ok, release_json()} end)
    |> expect(:download, fn _url, _path, _opts -> {:error, "Status 500 Internal Server Error"} end)

    assert {:error, msg} = GithubAPI.get(prepared, @invalid_download_path)
    assert msg =~ "Download failed"
  end

  test "valid artifact via API" do
    prepared = plan(method: :github_api, token: "1234")

    HTTPClient
    |> expect(:get_json, fn url, opts ->
      assert URI.to_string(url) == @release_api_url
      assert {"Authorization", "Bearer 1234"} in opts[:headers]
      {:ok, release_json()}
    end)
    |> expect(:download, fn url, path, opts ->
      assert url == @asset_api_url
      assert path == @good_download_path
      assert {"Accept", "application/octet-stream"} in opts[:headers]
      assert {"Authorization", "Bearer 1234"} in opts[:headers]
      :ok
    end)

    assert :ok = GithubAPI.get(prepared, @good_download_path)
  end

  test "username is ignored for backward compatibility" do
    prepared = plan(method: :github_api, token: "1234", username: "old_basic_auth_username")

    HTTPClient
    |> expect(:get_json, fn _url, opts ->
      assert {"Authorization", "Bearer 1234"} in opts[:headers]
      {:ok, release_json()}
    end)
    |> expect(:download, fn _url, _path, opts ->
      assert {"Authorization", "Bearer 1234"} in opts[:headers]
      :ok
    end)

    assert :ok = GithubAPI.get(prepared, @good_download_path)
  end

  test "GITHUB_TOKEN takes precedence" do
    env_token = "look-at-me!"
    gh_token = "dont-look-at-me!"

    System.put_env("GITHUB_TOKEN", env_token)
    System.put_env("GH_TOKEN", gh_token)

    prepared = plan(method: :github_api, token: "explicit_token")

    HTTPClient
    |> expect(:get_json, fn _url, opts ->
      assert {"Authorization", "Bearer " <> ^env_token} =
               List.keyfind(opts[:headers], "Authorization", 0)

      {:ok, release_json()}
    end)
    |> expect(:download, fn _url, _path, opts ->
      assert {"Authorization", "Bearer " <> ^env_token} =
               List.keyfind(opts[:headers], "Authorization", 0)

      :ok
    end)

    assert :ok = GithubAPI.get(prepared, @good_download_path)
  end

  test "supports GH_TOKEN shorthand" do
    env_token = "look-at-me!"

    System.put_env("GH_TOKEN", env_token)

    prepared = plan(method: :github_api)

    HTTPClient
    |> expect(:get_json, fn _url, opts ->
      assert {"Authorization", "Bearer " <> ^env_token} =
               List.keyfind(opts[:headers], "Authorization", 0)

      {:ok, release_json()}
    end)
    |> expect(:download, fn _url, _path, opts ->
      assert {"Authorization", "Bearer " <> ^env_token} =
               List.keyfind(opts[:headers], "Authorization", 0)

      :ok
    end)

    assert :ok = GithubAPI.get(prepared, @good_download_path)
  end

  # --- Other tests ---

  test "custom tag without token uses web URL" do
    prepared = plan(tag: "custom-tag")

    expected_url =
      URI.parse(
        "https://github.com/#{@org_repo}/releases/download/custom-tag/#{@artifact_filename}"
      )

    HTTPClient
    |> expect(:download, 1, fn url, _path, _opts ->
      assert url == expected_url
      :ok
    end)

    assert :ok = GithubAPI.get(prepared, @good_download_path)
  end

  test "custom tag with token uses API" do
    prepared = plan(method: :github_api, tag: "custom-tag", token: "1234")

    custom_release_url =
      "https://api.github.com/repos/#{@org_repo}/releases/tags/custom-tag"

    HTTPClient
    |> expect(:get_json, fn url, _opts ->
      assert URI.to_string(url) == custom_release_url
      {:ok, release_json()}
    end)
    |> expect(:download, fn url, _path, _opts ->
      assert url == @asset_api_url
      :ok
    end)

    assert :ok = GithubAPI.get(prepared, @good_download_path)
  end

  test "github_api site is supported for backward compatibility" do
    {GithubAPI, prepared} =
      GithubAPI.plan({:github_api, @org_repo, [token: "1234"]}, @version, @artifact_filename)

    HTTPClient
    |> expect(:get_json, fn url, _opts ->
      assert URI.to_string(url) == @release_api_url
      {:ok, release_json()}
    end)
    |> expect(:download, fn url, _path, opts ->
      assert url == @asset_api_url
      assert {"Authorization", "Bearer 1234"} in opts[:headers]
      :ok
    end)

    assert :ok = GithubAPI.get(prepared, @good_download_path)
  end

  test "unsupported site returns nil" do
    assert nil == GithubAPI.plan({:prefix, "https://example.com"}, @version, @artifact_filename)
  end

  test "github_release with token uses direct download" do
    prepared = plan(token: "1234")

    expected_url = URI.parse(@release_download_url)

    HTTPClient
    |> stub(:get_json, fn _, _ -> flunk("get_json should not be called for :github_release") end)
    |> expect(:download, fn url, _path, opts ->
      assert url == expected_url
      assert {"Authorization", "Bearer 1234"} in opts[:headers]
      :ok
    end)

    assert :ok = GithubAPI.get(prepared, @good_download_path)
  end

  test "github_api without token uses API" do
    prepared = plan(method: :github_api)

    HTTPClient
    |> expect(:get_json, fn url, opts ->
      assert URI.to_string(url) == @release_api_url
      assert opts[:headers] == []
      {:ok, release_json()}
    end)
    |> expect(:download, fn url, _path, opts ->
      assert url == @asset_api_url
      assert opts[:headers] == [{"Accept", "application/octet-stream"}]
      :ok
    end)

    assert :ok = GithubAPI.get(prepared, @good_download_path)
  end
end
