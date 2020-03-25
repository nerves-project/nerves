defmodule Nerves.UtilsTest do
  use NervesTest.Case

  # Special thanks to Hex

  alias Nerves.Utils

  test "proxy_config returns no credentials when no proxy supplied" do
    assert Utils.Proxy.config("http://nerves-project.org") == []
  end

  test "proxy_config returns http_proxy credentials when supplied" do
    System.put_env("HTTP_PROXY", "http://nerves:test@example.com")
    assert Utils.Proxy.config("http://nerves-project.org") == [proxy_auth: {'nerves', 'test'}]
    System.delete_env("HTTP_PROXY")
  end

  test "proxy_config returns http_proxy credentials when only username supplied" do
    System.put_env("HTTP_PROXY", "http://nopass@example.com")
    assert Utils.Proxy.config("http://nerves-project.org") == [proxy_auth: {'nopass', ''}]
    System.delete_env("HTTP_PROXY")
  end

  test "proxy_config returns credentials when the protocol is https" do
    System.put_env("HTTPS_PROXY", "https://test:nerves@example.com")
    assert Utils.Proxy.config("https://nerves-project.org") == [proxy_auth: {'test', 'nerves'}]
    System.delete_env("HTTPS_PROXY")
  end

  test "proxy_config returns empty list when no credentials supplied" do
    System.put_env("HTTP_PROXY", "http://example.com")
    assert Utils.Proxy.config("http://nerves-project.org") == []
    System.delete_env("HTTP_PROXY")
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

      :os.cmd('dd if=/dev/urandom bs=1024 count=1 of=#{archive_path}')
      assert {:error, _} = Utils.File.validate(archive_path)
    end)
  end

  test "validate extension programs" do
    assert String.equivalent?("gzip", Utils.File.ext_cmd(".gz"))
    assert String.equivalent?("xz", Utils.File.ext_cmd(".xz"))
    assert String.equivalent?("tar", Utils.File.ext_cmd(".tar"))
  end

  test "parse otp compiler versions" do
    assert {:ok, %Version{major: 1, minor: 2, patch: 3}} = Mix.Nerves.Utils.parse_version("1.2.3")

    assert {:ok, %Version{major: 1, minor: 2, patch: 0}} = Mix.Nerves.Utils.parse_version("1.2")

    assert {:ok, %Version{major: 1, minor: 2, patch: 3}} =
             Mix.Nerves.Utils.parse_version("1.2.3.4")

    assert {:error, _} = Mix.Nerves.Utils.parse_version("invalid")
  end

  defp create_archive(content_path, cwd) do
    file = "archive.tar.gz"
    Utils.File.tar(content_path, file)
    Path.join(cwd, file)
  end
end
