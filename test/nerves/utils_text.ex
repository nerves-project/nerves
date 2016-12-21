defmodule Nerves.UtilsTest do
  use NervesTest.Case, async: false
  # Special thanks to Hex

  test "proxy_config returns no credentials when no proxy supplied" do
    assert Nerves.Utils.Proxy.config("http://nerves-project.org") == []
  end

  test "proxy_config returns http_proxy credentials when supplied" do
    System.put_env("HTTP_PROXY", "http://nerves:test@example.com")
    assert Nerves.Utils.Proxy.config("http://nerves-project.org") == [proxy_auth: {'nerves', 'test'}]
    System.delete_env("HTTP_PROXY")
  end

  test "proxy_config returns http_proxy credentials when only username supplied" do
    System.put_env("HTTP_PROXY", "http://nopass@example.com")
    assert Nerves.Utils.Proxy.config("http://nerves-project.org") == [proxy_auth: {'nopass', ''}]
    System.delete_env("HTTP_PROXY")
  end

  test "proxy_config returns credentials when the protocol is https" do
    System.put_env("HTTPS_PROXY", "https://test:nerves@example.com")
    assert Nerves.Utils.Proxy.config("https://nerves-project.org") == [proxy_auth: {'test', 'nerves'}]
    System.delete_env("HTTPS_PROXY")
  end

  test "proxy_config returns empty list when no credentials supplied" do
    System.put_env("HTTP_PROXY", "http://example.com")
    assert Nerves.Utils.Proxy.config("http://nerves-project.org") == []
    System.delete_env("HTTP_PROXY")
  end

end
