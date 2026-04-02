# SPDX-FileCopyrightText: 2018 Justin Schneck
# SPDX-FileCopyrightText: 2021 Frank Hunleth
# SPDX-FileCopyrightText: 2021 Jon Thacker
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Artifact.DownloaderTest do
  use NervesTest.Case

  alias Nerves.Artifact.Downloader

  setup_all do
    {:ok, pid} = Nerves.TestServer.Router.start_link()
    [server: pid]
  end

  test "downloader can download from open sites" do
    in_fixture("resolver", fn ->
      set_artifact_path()

      sites = [
        {:prefix, "http://127.0.0.1:4000/no_auth/"}
      ]

      pkg = %{app: :example, version: "0.1.0", path: "./", config: [artifact_sites: sites]}

      downloaders = Downloader.expand_sites(pkg)
      assert {:ok, _path} = Downloader.download(downloaders, pkg)
    end)
  end

  test "downloader can download using query param token auth" do
    in_fixture("resolver", fn ->
      set_artifact_path()

      sites = [
        {:prefix, "http://127.0.0.1:4000/token_auth/", query_params: %{"id" => 1234}}
      ]

      pkg = %{app: :example, version: "0.1.0", path: "./", config: [artifact_sites: sites]}

      downloaders = Downloader.expand_sites(pkg)
      assert {:ok, _path} = Downloader.download(downloaders, pkg)
    end)
  end

  test "downloader can download using query param token auth with reserved chars" do
    in_fixture("resolver", fn ->
      set_artifact_path()

      sites = [
        {:prefix, "http://127.0.0.1:4000/token_auth/",
         query_params: %{"id" => ":/?#[]@!$&'()&+,;="}}
      ]

      pkg = %{app: :example, version: "0.1.0", path: "./", config: [artifact_sites: sites]}

      downloaders = Downloader.expand_sites(pkg)
      assert {:ok, _path} = Downloader.download(downloaders, pkg)
    end)
  end

  test "downloader unauthorized using incorrect token auth" do
    in_fixture("resolver", fn ->
      set_artifact_path()

      sites = [
        {:prefix, "http://127.0.0.1:4000/token_auth/", query_params: %{"id" => 5678}}
      ]

      pkg = %{app: :example, version: "0.1.0", path: "./", config: [artifact_sites: sites]}

      downloaders = Downloader.expand_sites(pkg)
      assert {:error, _reason} = Downloader.download(downloaders, pkg)
    end)
  end

  test "downloader can download using authorization header" do
    in_fixture("resolver", fn ->
      set_artifact_path()
      token = Base.encode64("abcd:1234")

      sites = [
        {:prefix, "http://127.0.0.1:4000/header_auth/",
         headers: %{"Authorization" => "basic #{token}"}}
      ]

      pkg = %{app: :example, version: "0.1.0", path: "./", config: [artifact_sites: sites]}

      downloaders = Downloader.expand_sites(pkg)
      assert {:ok, _path} = Downloader.download(downloaders, pkg)
    end)
  end

  test "downloader unauthorized using incorrect authorization header" do
    in_fixture("resolver", fn ->
      set_artifact_path()
      token = Base.encode64("abcd:5678")

      sites = [
        {:prefix, "http://127.0.0.1:4000/header_auth/",
         headers: %{"Authorization" => "basic #{token}"}}
      ]

      pkg = %{app: :example, version: "0.1.0", path: "./", config: [artifact_sites: sites]}

      downloaders = Downloader.expand_sites(pkg)
      assert {:error, _} = Downloader.download(downloaders, pkg)
    end)
  end

  test "download validations will raise" do
    in_fixture("resolver", fn ->
      set_artifact_path()

      sites = [
        {:prefix, "http://127.0.0.1:4000/corrupt/"}
      ]

      pkg = %{app: :example, version: "0.1.0", path: "./", config: [artifact_sites: sites]}

      downloaders = Downloader.expand_sites(pkg)

      assert_raise Mix.Error, fn ->
        Downloader.download(downloaders, pkg)
      end
    end)
  end

  test "download validations will not raise if eventually successful" do
    in_fixture("resolver", fn ->
      set_artifact_path()

      sites = [
        {:prefix, "http://127.0.0.1:4000/corrupt/"},
        {:prefix, "http://127.0.0.1:4000/no_auth/"}
      ]

      pkg = %{app: :example, version: "0.1.0", path: "./", config: [artifact_sites: sites]}

      downloaders = Downloader.expand_sites(pkg)

      assert {:ok, _path} = Downloader.download(downloaders, pkg)
    end)
  end

  test "http downloader status codes are rendered" do
    in_fixture("resolver", fn ->
      sites = [
        {:prefix, "http://127.0.0.1:4000/doe_not_exist/"}
      ]

      pkg = %{app: :example, version: "0.1.0", path: "./", config: [artifact_sites: sites]}

      downloaders = Downloader.expand_sites(pkg)

      assert {:error, _reason} = Downloader.download(downloaders, pkg)
      output = "     Status 404 Not Found"
      assert_receive {:mix_shell, :info, [^output]}
    end)
  end

  defp set_artifact_path() do
    # Test tar file for artifact test server
    artifact_tar = Path.join([File.cwd!(), "artifact.tar.gz"])
    corrupt_artifact_tar = Path.join([File.cwd!(), "corrupt.tar.gz"])
    System.put_env("TEST_ARTIFACT_TAR", artifact_tar)
    System.put_env("TEST_ARTIFACT_TAR_CORRUPT", corrupt_artifact_tar)
  end
end
