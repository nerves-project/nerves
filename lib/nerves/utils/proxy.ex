# SPDX-FileCopyrightText: 2016 Justin Schneck
# SPDX-FileCopyrightText: 2017 Zander Mackie
# SPDX-FileCopyrightText: 2022 Frank Hunleth
# SPDX-FileCopyrightText: 2022 Jon Carstens
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Utils.Proxy do
  @moduledoc false

  @http_proxy_key "HTTP_PROXY"
  @https_proxy_key "HTTPS_PROXY"

  @doc """
  Return additional request options for the specified URL
  """
  @spec request_options(URI.t() | String.t()) :: [proxy_auth: {charlist(), charlist()}]
  def request_options(url) do
    case URI.parse(url) do
      %URI{scheme: "http"} -> get_env_url(@http_proxy_key) |> auth()
      %URI{scheme: "https"} -> get_env_url(@https_proxy_key) |> auth()
      _ -> []
    end
  end

  @doc """
  Return proxy options for configuring an httpc profile
  """
  @spec httpc_options() :: keyword()
  def httpc_options() do
    http_proxy = get_env_url(@http_proxy_key)
    https_proxy = get_env_url(@https_proxy_key)
    httpc_options(http_proxy, https_proxy)
  end

  defp get_env_url(key), do: System.get_env(key) |> may_parse_uri()
  defp may_parse_uri(nil), do: nil
  defp may_parse_uri(uri), do: URI.parse(uri)

  defp httpc_options(http_proxy, https_proxy) do
    httpc_option(:proxy, http_proxy) ++ httpc_option(:https_proxy, https_proxy)
  end

  defp httpc_option(key, %URI{host: host, port: port})
       when is_binary(host) and is_integer(port) do
    host = String.to_charlist(host)
    [{key, {{host, port}, []}}]
  end

  defp httpc_option(_key, _uri), do: []

  defp auth(%URI{userinfo: auth}) when is_binary(auth) do
    destructure [user, pass], String.split(auth, ":", parts: 2)

    user = String.to_charlist(user)
    pass = String.to_charlist(pass || "")

    [proxy_auth: {user, pass}]
  end

  defp auth(_uri), do: []
end
