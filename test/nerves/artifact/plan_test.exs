# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Artifact.PlanTest do
  use ExUnit.Case

  alias Nerves.Artifact
  alias Nerves.Artifact.Resolvers.GiteaAPI
  alias Nerves.Artifact.Resolvers.GithubAPI
  alias Nerves.Artifact.Resolvers.URI, as: URIResolver

  @version "1.0.0"

  @pkg %{
    app: "my_system",
    version: @version,
    type: :system,
    path: "./",
    config: []
  }

  @artifact_filename "my_system-portable-#{@version}-AABBCCDD.tar.gz"

  setup do
    System.delete_env("GITHUB_TOKEN")
    System.delete_env("GH_TOKEN")
    System.delete_env("GITEA_TOKEN")
    :ok
  end

  describe "GithubAPI.plan/3" do
    test "github_releases defaults to public with version tag" do
      {GithubAPI, %GithubAPI{} = opts} =
        GithubAPI.plan({:github_releases, "org/repo"}, @version, @artifact_filename)

      assert opts.tag == "v1.0.0"
      assert opts.org_repo == "org/repo"
      assert opts.web_url == URI.parse("https://github.com")
      assert opts.artifact_filename == @artifact_filename
    end

    test "github_releases with custom tag" do
      {GithubAPI, %GithubAPI{} = opts} =
        GithubAPI.plan(
          {:github_releases, "org/repo", tag: "custom"},
          @version,
          @artifact_filename
        )

      assert opts.tag == "custom"
    end

    test "github_api sets auth token from explicit token" do
      {GithubAPI, %GithubAPI{} = opts} =
        GithubAPI.plan(
          {:github_api, "org/repo", token: "ghp_secret"},
          @version,
          @artifact_filename
        )

      assert opts.custom_auth_token == "ghp_secret"
    end

    test "artifact name includes checksum" do
      checksum_short = Artifact.checksum(@pkg, short: 7)
      artifact_name = Artifact.download_name(@pkg) <> Artifact.ext(@pkg)

      {GithubAPI, %GithubAPI{} = opts} =
        GithubAPI.plan({:github_releases, "org/repo"}, @version, artifact_name)

      assert String.contains?(opts.artifact_filename, checksum_short)
    end

    test "unsupported site returns nil" do
      assert nil == GithubAPI.plan({:prefix, "https://example.com"}, @version, @artifact_filename)
    end
  end

  describe "GiteaAPI.plan/3" do
    test "gitea_releases parses full URL" do
      {GiteaAPI, %GiteaAPI{} = opts} =
        GiteaAPI.plan(
          {:gitea_releases, "https://gitea.example.com/org/repo"},
          @version,
          @artifact_filename
        )

      assert opts.tag == "v1.0.0"
      assert opts.org_repo_url == URI.parse("https://gitea.example.com/org/repo")
    end

    test "gitea_releases parses bare host/org/repo" do
      {GiteaAPI, %GiteaAPI{} = opts} =
        GiteaAPI.plan(
          {:gitea_releases, "gitea.example.com/org/repo"},
          @version,
          @artifact_filename
        )

      assert opts.org_repo_url == URI.parse("https://gitea.example.com/org/repo")
    end

    test "gitea_api sets token auth" do
      {GiteaAPI, %GiteaAPI{} = opts} =
        GiteaAPI.plan(
          {:gitea_api, "org/repo", base_url: "https://git.co/", token: "gitea_secret"},
          @version,
          @artifact_filename
        )

      assert opts.auth_token == "gitea_secret"
    end

    test "GITEA_TOKEN from env" do
      System.put_env("GITEA_TOKEN", "env_gitea")

      {GiteaAPI, %GiteaAPI{} = opts} =
        GiteaAPI.plan(
          {:gitea_releases, "gitea.example.com/org/repo"},
          @version,
          @artifact_filename
        )

      assert opts.auth_token == "env_gitea"
    end

    test "artifact name includes checksum" do
      checksum_short = Artifact.checksum(@pkg, short: 7)
      artifact_name = Artifact.download_name(@pkg) <> Artifact.ext(@pkg)

      {GiteaAPI, %GiteaAPI{} = opts} =
        GiteaAPI.plan(
          {:gitea_releases, "gitea.example.com/org/repo"},
          @version,
          artifact_name
        )

      assert String.contains?(opts.artifact_filename, checksum_short)
    end

    test "unsupported site returns nil" do
      assert nil ==
               GiteaAPI.plan({:github_releases, "org/repo"}, @version, @artifact_filename)
    end
  end

  describe "URIResolver.plan/3" do
    test "prefix builds full path" do
      {URIResolver, %{uri: uri, headers: []}} =
        URIResolver.plan({:prefix, "https://dl.example.com"}, @version, @artifact_filename)

      uri_string = URI.to_string(uri)
      assert String.starts_with?(uri_string, "https://dl.example.com/")
      assert String.contains?(uri_string, @artifact_filename)
    end

    test "prefix passes resolver opts through" do
      {URIResolver, %{uri: uri}} =
        URIResolver.plan(
          {:prefix, "https://dl.example.com", query_params: %{"id" => "123"}},
          @version,
          @artifact_filename
        )

      assert URI.to_string(uri) =~ "id=123"
    end

    test "unsupported site returns nil" do
      assert nil ==
               URIResolver.plan({:github_releases, "org/repo"}, @version, @artifact_filename)
    end
  end

  describe "Artifact.expand_sites/1 integration" do
    test "github_releases goes through plan" do
      pkg = %{@pkg | config: [artifact_sites: [{:github_releases, "org/repo"}]]}

      [{GithubAPI, %GithubAPI{} = opts}] = Artifact.expand_sites(pkg)
      assert opts.org_repo == "org/repo"
      assert opts.tag == "v1.0.0"
    end

    test "gitea_releases goes through plan" do
      pkg = %{@pkg | config: [artifact_sites: [{:gitea_releases, "gitea.co/org/repo"}]]}

      [{GiteaAPI, %GiteaAPI{} = opts}] = Artifact.expand_sites(pkg)
      assert opts.org_repo_url == URI.parse("https://gitea.co/org/repo")
    end

    test "prefix goes through plan" do
      pkg = %{@pkg | config: [artifact_sites: [{:prefix, "https://dl.example.com"}]]}

      [{URIResolver, opts}] = Artifact.expand_sites(pkg)

      assert opts.uri ==
               URI.parse("https://dl.example.com/my_system-portable-1.0.0-E3B0C44.tar.gz")
    end
  end
end
