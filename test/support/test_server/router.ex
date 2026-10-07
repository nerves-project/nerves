# SPDX-FileCopyrightText: 2018 Justin Schneck
# SPDX-FileCopyrightText: 2021 Jon Thacker
# SPDX-FileCopyrightText: 2022 Frank Hunleth
# SPDX-FileCopyrightText: 2022 Jon Carstens
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.TestServer.Router do
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(_options) do
    bandit_opts = [plug: Nerves.TestServer.Router, port: 4000]

    %{
      id: Nerves.TestServer.Router,
      start: {Bandit, :start_link, [bandit_opts]}
    }
  end

  get "/no_auth/*_" do
    conn
    |> send_file(200, System.get_env("TEST_ARTIFACT_TAR"))
  end

  get "/token_auth/*_" do
    query_params =
      conn
      |> fetch_query_params()
      |> Map.get(:query_params)

    case Map.get(query_params, "id", "") do
      "1234" ->
        send_file(conn, 200, System.get_env("TEST_ARTIFACT_TAR"))

      ":/?#[]@!$&'()&+,;=" ->
        send_file(conn, 200, System.get_env("TEST_ARTIFACT_TAR"))

      _ ->
        conn
        |> send_resp(401, "Unauthorized")
        |> Plug.Conn.halt()
    end
  end

  get "/header_auth/*_" do
    ["basic " <> authorization] =
      conn
      |> get_req_header("authorization")

    if Base.decode64!(authorization) == "abcd:1234" do
      send_file(conn, 200, System.get_env("TEST_ARTIFACT_TAR"))
    else
      conn
      |> send_resp(401, "Unauthorized")
      |> Plug.Conn.halt()
    end
  end

  get "/corrupt/*_" do
    send_file(conn, 200, System.get_env("TEST_ARTIFACT_TAR_CORRUPT"))
  end

  get "/json/ok" do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{hello: "world", number: 42}))
  end

  get "/json/invalid" do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, "not valid json{{{")
  end

  get "/json/not_found" do
    conn
    |> send_resp(404, "Not Found")
    |> Plug.Conn.halt()
  end

  get "/redirect/absolute" do
    conn
    |> put_resp_header("location", "http://127.0.0.1:4000/json/ok")
    |> send_resp(302, "")
  end

  get "/redirect/root_relative" do
    conn
    |> put_resp_header("location", "/json/ok")
    |> send_resp(302, "")
  end

  get "/redirect/path_relative" do
    conn
    |> put_resp_header("location", "../json/ok")
    |> send_resp(302, "")
  end

  get "/redirect/scheme_relative" do
    conn
    |> put_resp_header("location", "//127.0.0.1:4000/json/ok")
    |> send_resp(302, "")
  end

  get "/redirect/loop" do
    conn
    |> put_resp_header("location", "/redirect/loop")
    |> send_resp(302, "")
  end

  match _ do
    conn
    |> send_resp(404, "Not Found")
    |> Plug.Conn.halt()
  end
end
