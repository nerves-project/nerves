# SPDX-FileCopyrightText: 2018 Justin Schneck
# SPDX-FileCopyrightText: 2022 Frank Hunleth
# SPDX-FileCopyrightText: 2023 Jon Carstens
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.UtilsTest do
  use NervesTest.Case

  alias Nerves.Utils
  alias Nerves.Utils.Proxy

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

  test "proxy config returns no credentials when no proxy supplied" do
    assert Proxy.request_options("http://nerves-project.org") == []
    assert Proxy.httpc_options() == []
  end

  test "proxy config returns http_proxy credentials when supplied" do
    System.put_env("HTTP_PROXY", "http://nerves:test@example.com")

    assert Proxy.request_options("http://nerves-project.org") == [
             proxy_auth: {~c"nerves", ~c"test"}
           ]

    assert Proxy.httpc_options() == [{:proxy, {{~c"example.com", 80}, []}}]
  end

  test "proxy config returns http_proxy credentials when only username supplied" do
    System.put_env("HTTP_PROXY", "http://nopass@example.com")
    assert Proxy.request_options("http://nerves-project.org") == [proxy_auth: {~c"nopass", ~c""}]
    assert Proxy.httpc_options() == [{:proxy, {{~c"example.com", 80}, []}}]
  end

  test "proxy config returns credentials when the protocol is https" do
    System.put_env("HTTPS_PROXY", "https://test:nerves@example.com")

    assert Proxy.request_options("https://nerves-project.org") == [
             proxy_auth: {~c"test", ~c"nerves"}
           ]

    assert Proxy.httpc_options() == [{:https_proxy, {{~c"example.com", 443}, []}}]
  end

  test "proxy config returns empty list when no credentials supplied" do
    System.put_env("HTTP_PROXY", "http://example.com:123")
    assert Proxy.request_options("http://nerves-project.org") == []
    assert Proxy.httpc_options() == [{:proxy, {{~c"example.com", 123}, []}}]
  end

  test "proxy config returns both http and https" do
    System.put_env("HTTP_PROXY", "http://test:nerves@http_proxy.com")
    System.put_env("HTTPS_PROXY", "https://test:nerves@https_proxy.com")

    assert Proxy.httpc_options() == [
             {:proxy, {{~c"http_proxy.com", 80}, []}},
             {:https_proxy, {{~c"https_proxy.com", 443}, []}}
           ]
  end

  test "create tar archives", context do
    in_tmp(context.test, fn ->
      cwd = File.cwd!()
      content_path = Path.join(cwd, "content")
      File.mkdir(content_path)
      contents = Path.join(content_path, "file")
      File.touch(contents)
      archive = create_archive(content_path, cwd)
      assert File.exists?(archive)
    end)
  end

  test "decompress tar archives", context do
    in_tmp(context.test, fn ->
      cwd = File.cwd!()
      content_path = Path.join(cwd, "content")
      File.mkdir(content_path)
      contents = Path.join(content_path, "file")
      File.touch(contents)
      archive = create_archive(content_path, cwd)
      assert File.exists?(archive)
      File.rm_rf!(content_path)
      File.mkdir(content_path)
      Utils.File.untar(archive, content_path)
      assert File.exists?(contents)
    end)
  end

  test "validate tar archives", context do
    in_tmp(context.test, fn ->
      cwd = File.cwd!()
      archive_path = Path.join(cwd, "archive.tar.gz")

      {_, 0} =
        System.cmd("dd", ["if=/dev/urandom", "bs=1024", "count=1", "of=#{archive_path}"],
          stderr_to_stdout: true
        )

      assert {:error, _} = Utils.File.validate(archive_path)
    end)
  end

  test "validate extension programs" do
    assert Utils.File.ext_cmd(".gz") == "gzip"
    assert Utils.File.ext_cmd(".xz") == "xz"
    assert Utils.File.ext_cmd(".tar") == "tar"
  end

  defp create_archive(content_path, cwd) do
    file = "archive.tar.gz"
    Utils.File.tar(content_path, file)
    Path.join(cwd, file)
  end
end
