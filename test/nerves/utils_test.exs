defmodule Nerves.UtilsTest do
  use NervesTest.Case

  # Special thanks to Hex

  alias Nerves.Utils

  test "proxy_config returns no credentials when no proxy supplied" do
    assert Utils.Proxy.config("http://nerves-project.org") == []
  end

  test "proxy_config returns http_proxy credentials when supplied" do
    System.put_env("HTTP_PROXY", "http://nerves:test@example.com")
    assert Utils.Proxy.config("http://nerves-project.org") == [proxy_auth: {~c"nerves", ~c"test"}]
    System.delete_env("HTTP_PROXY")
  end

  test "proxy_config returns http_proxy credentials when only username supplied" do
    System.put_env("HTTP_PROXY", "http://nopass@example.com")
    assert Utils.Proxy.config("http://nerves-project.org") == [proxy_auth: {~c"nopass", ~c""}]
    System.delete_env("HTTP_PROXY")
  end

  test "proxy_config returns credentials when the protocol is https" do
    System.put_env("HTTPS_PROXY", "https://test:nerves@example.com")

    assert Utils.Proxy.config("https://nerves-project.org") == [
             proxy_auth: {~c"test", ~c"nerves"}
           ]

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
