# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.TestServer do
  @moduledoc false
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(_options) do
    bandit_opts = [plug: __MODULE__, port: 4000]

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

  match _ do
    conn
    |> send_resp(404, "Not Found")
    |> Plug.Conn.halt()
  end
end
