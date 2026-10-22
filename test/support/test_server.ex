# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.TestServer do
  @moduledoc false
  use Plug.Router

  @port 4567

  plug(:match)
  plug(:dispatch)

  @spec port() :: pos_integer()
  def port(), do: @port

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(_options) do
    bandit_opts = [plug: __MODULE__, port: @port]

    %{
      id: __MODULE__,
      start: {Bandit, :start_link, [bandit_opts]}
    }
  end

  get "/text" do
    send_resp(conn, 200, "hello nerves")
  end

  get "/json/ok" do
    body = :json.encode(%{"hello" => "world", "number" => 42})

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, body)
  end

  get "/json/invalid" do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, "not valid json{{{")
  end

  get "/binary" do
    # 1 KB of recognizable binary content
    body = :binary.copy(<<0xDE, 0xAD, 0xBE, 0xEF>>, 256)

    conn
    |> put_resp_content_type("application/octet-stream")
    |> send_resp(200, body)
  end

  get "/precompiled/root.json" do
    serve_json(conn, Nerves.PrecompiledFixture.get(:root))
  end

  get "/precompiled/batch.json" do
    serve_json(conn, Nerves.PrecompiledFixture.get(:batch))
  end

  get "/precompiled/manifests/:name" do
    name = String.replace_suffix(name, ".json", "")

    case get_in(Nerves.PrecompiledFixture.get(:manifests) || %{}, [name]) do
      nil -> send_resp(conn, 404, "not found")
      bytes -> conn |> put_resp_content_type("application/json") |> send_resp(200, bytes)
    end
  end

  get "/precompiled/files/:sha" do
    case get_in(Nerves.PrecompiledFixture.get(:files) || %{}, [sha]) do
      nil -> send_resp(conn, 404, "not found")
      bytes -> conn |> put_resp_content_type("application/octet-stream") |> send_resp(200, bytes)
    end
  end

  get "/precompiled/redirect/*rest" do
    conn
    |> put_resp_header(
      "location",
      "http://127.0.0.2:#{@port}/precompiled/" <> Enum.join(rest, "/")
    )
    |> send_resp(302, "")
  end

  defp serve_json(conn, nil), do: send_resp(conn, 503, "none")

  defp serve_json(conn, map),
    do: conn |> put_resp_content_type("application/json") |> send_resp(200, :json.encode(map))

  match _ do
    conn
    |> send_resp(404, "Not Found")
    |> Plug.Conn.halt()
  end
end
