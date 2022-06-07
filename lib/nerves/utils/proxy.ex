defmodule Nerves.Utils.Proxy do
  @moduledoc false
  # Special thanks to Hex.

  @spec config(String.t()) :: [proxy_auth: {charlist(), charlist()}]
  def config(url) do
    {http_proxy, https_proxy} = setup()
    auth(URI.parse(url), http_proxy, https_proxy)
  end

  defp setup() do
    http_proxy = (proxy = System.get_env("HTTP_PROXY")) && set(:http, proxy)
    https_proxy = (proxy = System.get_env("HTTPS_PROXY")) && set(:https, proxy)
    {http_proxy, https_proxy}
  end

  defp set(scheme, proxy) do
    uri = URI.parse(proxy)

    _ =
      if uri.host && uri.port do
        host = String.to_charlist(uri.host)
        :httpc.set_options([{scheme(scheme), {{host, uri.port}, []}}], :nerves)
      end

    uri
  end

  defp scheme(scheme) do
    case scheme do
      :http -> :proxy
      :https -> :https_proxy
    end
  end

  defp auth(%URI{scheme: "http"}, http_proxy, _https_proxy), do: auth(http_proxy)
  defp auth(%URI{scheme: "https"}, _http_proxy, https_proxy), do: auth(https_proxy)

  defp auth(nil), do: []
  defp auth(%URI{userinfo: nil}), do: []

  defp auth(%URI{userinfo: auth}) do
    destructure [user, pass], String.split(auth, ":", parts: 2)

    user = String.to_charlist(user)
    pass = String.to_charlist(pass || "")

    [proxy_auth: {user, pass}]
  end
end
