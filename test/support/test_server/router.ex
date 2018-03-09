defmodule Nerves.TestServer.Router do
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  def start_link do
    Plug.Adapters.Cowboy.http(Nerves.TestServer.Router, [])
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

    if Map.get(query_params, "id", "") == "1234" do
      send_file(conn, 200, System.get_env("TEST_ARTIFACT_TAR"))
    else
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

  match _ do
    # IO.puts "Catch All"
    # IO.inspect conn
    conn
    |> send_resp(404, "Not Found")
    |> Plug.Conn.halt()
  end
end
