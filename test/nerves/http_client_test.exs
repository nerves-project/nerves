# SPDX-FileCopyrightText: 2018 Justin Schneck
# SPDX-FileCopyrightText: 2022 Frank Hunleth
# SPDX-FileCopyrightText: 2023 Jon Carstens
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.HTTPClientTest do
  use ExUnit.Case, async: false

  alias Nerves.HTTPClient

  @base_url "http://127.0.0.1:4000"

  setup_all do
    pid = start_supervised!(Nerves.TestServer)
    [server: pid]
  end

  setup do
    _ = :inets.start(:httpc, profile: :nerves)

    on_exit(fn ->
      # Stop the httpc profile to clear proxy settings that persist
      # and would otherwise poison the :nerves profile for resolver tests
      _ = :inets.stop(:httpc, :nerves)
      System.delete_env("HTTP_PROXY")
      System.delete_env("HTTPS_PROXY")
    end)
  end

  describe "get/2" do
    test "fetches text content" do
      assert {:ok, "hello nerves"} = HTTPClient.get("#{@base_url}/text")
    end

    test "collects into a custom collectable" do
      assert {:ok, ["hello nerves"]} = HTTPClient.get("#{@base_url}/text", into: [])
    end

    test "returns error on 404" do
      assert {:error, "Status 404 Not Found"} = HTTPClient.get("#{@base_url}/missing")
    end
  end

  describe "get_json/2" do
    test "decodes a valid JSON response" do
      assert {:ok, %{"hello" => "world", "number" => 42}} =
               HTTPClient.get_json("#{@base_url}/json/ok")
    end

    test "returns error on invalid JSON" do
      assert {:error, _reason} = HTTPClient.get_json("#{@base_url}/json/invalid")
    end

    test "returns error on HTTP failure" do
      assert {:error, "Status 404 Not Found"} =
               HTTPClient.get_json("#{@base_url}/missing")
    end

    test "passes custom headers" do
      assert {:ok, %{"hello" => "world"}} =
               HTTPClient.get_json("#{@base_url}/json/ok",
                 headers: [{"X-Custom", "test"}]
               )
    end
  end

  describe "download/3" do
    @describetag :tmp_dir

    test "downloads to a file", %{tmp_dir: tmp} do
      dest = Path.join(tmp, "downloaded.bin")

      assert :ok = HTTPClient.download("#{@base_url}/binary", dest)
      assert File.exists?(dest)
      assert byte_size(File.read!(dest)) == 1024
    end

    test "cleans up on HTTP error", %{tmp_dir: tmp} do
      dest = Path.join(tmp, "should_not_exist.bin")

      assert {:error, _} = HTTPClient.download("#{@base_url}/missing", dest)
      refute File.exists?(dest)
    end
  end

  describe "proxy_request_options/1" do
    test "returns no credentials when no proxy supplied" do
      assert HTTPClient.proxy_request_options("http://nerves-project.org") == []
      assert HTTPClient.proxy_httpc_options() == []
    end

    test "returns http_proxy credentials when supplied" do
      System.put_env("HTTP_PROXY", "http://nerves:test@example.com")

      assert HTTPClient.proxy_request_options("http://nerves-project.org") == [
               proxy_auth: {~c"nerves", ~c"test"}
             ]

      assert HTTPClient.proxy_httpc_options() == [{:proxy, {{~c"example.com", 80}, []}}]
    end

    test "returns http_proxy credentials when only username supplied" do
      System.put_env("HTTP_PROXY", "http://nopass@example.com")

      assert HTTPClient.proxy_request_options("http://nerves-project.org") == [
               proxy_auth: {~c"nopass", ~c""}
             ]

      assert HTTPClient.proxy_httpc_options() == [{:proxy, {{~c"example.com", 80}, []}}]
    end

    test "returns credentials when the protocol is https" do
      System.put_env("HTTPS_PROXY", "https://test:nerves@example.com")

      assert HTTPClient.proxy_request_options("https://nerves-project.org") == [
               proxy_auth: {~c"test", ~c"nerves"}
             ]

      assert HTTPClient.proxy_httpc_options() == [
               {:https_proxy, {{~c"example.com", 443}, []}}
             ]
    end

    test "returns empty list when no credentials supplied" do
      System.put_env("HTTP_PROXY", "http://example.com:123")
      assert HTTPClient.proxy_request_options("http://nerves-project.org") == []
      assert HTTPClient.proxy_httpc_options() == [{:proxy, {{~c"example.com", 123}, []}}]
    end

    test "returns both http and https" do
      System.put_env("HTTP_PROXY", "http://test:nerves@http_proxy.com")
      System.put_env("HTTPS_PROXY", "https://test:nerves@https_proxy.com")

      assert HTTPClient.proxy_httpc_options() == [
               {:proxy, {{~c"http_proxy.com", 80}, []}},
               {:https_proxy, {{~c"https_proxy.com", 443}, []}}
             ]
    end
  end
end
