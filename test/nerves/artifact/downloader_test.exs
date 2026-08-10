# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Artifact.DownloaderTest do
  use ExUnit.Case

  alias Nerves.Artifact.Downloader.Gitea
  alias Nerves.Artifact.Downloader.GitHub
  alias Nerves.Artifact.Downloader.Prefix

  @version "1.0.0"
  @artifact_filename "my_system-portable-#{@version}-ABC1234.tar.gz"

  setup do
    System.delete_env("GITHUB_TOKEN")
    System.delete_env("GH_TOKEN")
    System.delete_env("GITEA_TOKEN")
    :ok
  end

  describe "GitHub.plan/3" do
    test "github_releases defaults to version tag and release method" do
      {GitHub, %GitHub{} = plan} =
        GitHub.plan({:github_releases, "org/repo"}, @version, @artifact_filename)

      assert plan.tag == "v1.0.0"
      assert plan.org_repo == "org/repo"
      assert plan.artifact_filename == @artifact_filename
      assert plan.web_url == URI.parse("https://github.com")
      assert plan.api_url == URI.parse("https://api.github.com")
      assert plan.method == :github_release
    end

    test "github_releases with custom tag" do
      {GitHub, plan} =
        GitHub.plan({:github_releases, "org/repo", tag: "custom"}, @version, @artifact_filename)

      assert plan.tag == "custom"
    end

    test "github_releases with custom github_url has nil api_url" do
      {GitHub, plan} =
        GitHub.plan(
          {:github_releases, "org/repo", github_url: "https://ghe.myco.com"},
          @version,
          @artifact_filename
        )

      assert plan.web_url == URI.parse("https://ghe.myco.com")
      assert plan.api_url == nil
    end

    test "github_api uses api method" do
      {GitHub, plan} =
        GitHub.plan(
          {:github_api, "org/repo", token: "ghp_secret"},
          @version,
          @artifact_filename
        )

      assert plan.method == :github_api
      assert plan.custom_auth_token == "ghp_secret"
      assert plan.api_url == URI.parse("https://api.github.com")
      assert plan.web_url == URI.parse("https://github.com")
    end

    test "github_api with custom github_url has nil web_url" do
      {GitHub, plan} =
        GitHub.plan(
          {:github_api, "org/repo",
           token: "ghp_secret", github_url: "https://ghe.myco.com/api/v3"},
          @version,
          @artifact_filename
        )

      assert plan.api_url == URI.parse("https://ghe.myco.com/api/v3")
      assert plan.web_url == nil
    end

    test "use_gh_cli? defaults to true" do
      {GitHub, plan} =
        GitHub.plan({:github_releases, "org/repo"}, @version, @artifact_filename)

      assert plan.use_gh_cli? == true
    end

    test "use_gh_cli? can be disabled" do
      {GitHub, plan} =
        GitHub.plan(
          {:github_releases, "org/repo", use_gh_cli?: false},
          @version,
          @artifact_filename
        )

      assert plan.use_gh_cli? == false
    end

    test "unsupported site returns nil" do
      assert nil == GitHub.plan({:prefix, "https://example.com"}, @version, @artifact_filename)
    end
  end

  describe "Gitea.plan/3" do
    test "gitea_releases uses release method" do
      {Gitea, %Gitea{} = plan} =
        Gitea.plan(
          {:gitea_releases, "https://gitea.example.com/org/repo"},
          @version,
          @artifact_filename
        )

      assert plan.tag == "v1.0.0"
      assert plan.artifact_filename == @artifact_filename
      assert plan.org_repo_url == URI.parse("https://gitea.example.com/org/repo")
      assert plan.method == :gitea_release
      assert plan.api_url == nil
    end

    test "gitea_releases parses bare host/org/repo" do
      {Gitea, plan} =
        Gitea.plan(
          {:gitea_releases, "gitea.example.com/org/repo"},
          @version,
          @artifact_filename
        )

      assert plan.org_repo_url == URI.parse("https://gitea.example.com/org/repo")
    end

    test "gitea_api uses api method with separate URLs" do
      {Gitea, plan} =
        Gitea.plan(
          {:gitea_api, "org/repo", base_url: "https://git.co/", token: "gitea_secret"},
          @version,
          @artifact_filename
        )

      assert plan.method == :gitea_api
      assert plan.auth_token == "gitea_secret"
      assert plan.org_repo_url == URI.parse("https://git.co/org/repo")
      assert plan.api_url == URI.parse("https://git.co/api/v1/repos/org/repo")
    end

    test "GITEA_TOKEN from env" do
      System.put_env("GITEA_TOKEN", "env_gitea")

      {Gitea, plan} =
        Gitea.plan(
          {:gitea_releases, "gitea.example.com/org/repo"},
          @version,
          @artifact_filename
        )

      assert plan.auth_token == "env_gitea"
    end

    test "unsupported site returns nil" do
      assert nil == Gitea.plan({:github_releases, "org/repo"}, @version, @artifact_filename)
    end
  end

  describe "Prefix.plan/3" do
    test "builds URI with filename" do
      {Prefix, plan} =
        Prefix.plan({:prefix, "https://dl.example.com"}, @version, @artifact_filename)

      assert plan.headers == []
      assert plan.artifact_filename == @artifact_filename
      assert URI.to_string(plan.uri) =~ @artifact_filename
    end

    test "passes headers through" do
      {Prefix, plan} =
        Prefix.plan(
          {:prefix, "https://dl.example.com", headers: [{"Authorization", "Basic abc"}]},
          @version,
          @artifact_filename
        )

      assert plan.headers == [{"Authorization", "Basic abc"}]
    end

    test "query_params are appended to URL" do
      {Prefix, plan} =
        Prefix.plan(
          {:prefix, "https://dl.example.com", query_params: %{"token" => "xyz"}},
          @version,
          @artifact_filename
        )

      assert URI.to_string(plan.uri) =~ "token=xyz"
    end

    test "unsupported site returns nil" do
      assert nil == Prefix.plan({:github_releases, "org/repo"}, @version, @artifact_filename)
    end
  end
end
