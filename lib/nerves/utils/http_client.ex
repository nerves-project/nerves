defmodule Nerves.Utils.HTTPClient do
  @moduledoc false
  use GenServer

  @progress_steps 50

  # See https://www.erlang.org/doc/man/httpc.html#request-5
  @type http_opts ::
          {:timeout, timeout()}
          | {:connect_timeout, timeout()}
          | {:ssl, [:ssl.tls_option()]}
          | {:essl, [:ssl.tls_option()]}
          | {:autoredirect, boolean()}
          | {:proxy_auth, {charlist(), charlist()}}
          | {:relaxed, boolean()}
  @type opts :: [
          progress?: boolean(),
          headers: [{String.t() | charlist(), String.t() | charlist()}],
          http_opts: http_opts()
        ]

  @spec start_link() :: GenServer.on_start()
  def start_link() do
    {:ok, _} = Application.ensure_all_started(:nerves)
    _ = start_httpc()
    GenServer.start_link(__MODULE__, [])
  end

  @spec stop(GenServer.server()) :: :ok
  def stop(pid) do
    GenServer.stop(pid)
  end

  @spec get(GenServer.server(), URI.t() | String.t(), opts()) ::
          {:ok, String.t()} | {:error, String.t() | :too_many_redirects | atom()}
  def get(_, _, _ \\ [])

  def get(_pid, %URI{host: nil, path: path}, _opts) do
    path
    |> Path.expand()
    |> File.read()
  end

  def get(pid, %URI{} = uri, opts) do
    url = URI.to_string(uri)
    get(pid, url, opts)
  end

  def get(pid, url, opts), do: GenServer.call(pid, {:get, url, opts}, :infinity)

  @impl GenServer
  def init([]) do
    {:ok,
     %{
       url: nil,
       content_length: 0,
       buffer: "",
       buffer_size: 0,
       filename: "",
       caller: nil,
       number_of_redirects: 0,
       progress?: true,
       get_opts: []
     }}
  end

  @impl GenServer
  def handle_call({:get, _url, _opts}, _from, %{number_of_redirects: n} = s) when n > 5 do
    GenServer.reply(s.caller, {:error, :too_many_redirects})
    {:noreply, %{s | url: nil, number_of_redirects: 0, caller: nil}}
  end

  def handle_call({:get, url, opts}, from, s) do
    progress? = Keyword.get(opts, :progress?, true)

    user_headers = Keyword.get(opts, :headers, []) |> Enum.map(&tuple_to_charlist/1)

    headers = [
      {~c"User-Agent", ~c"Nerves/#{Nerves.version()}"},
      {~c"Content-Type", ~c"application/octet-stream"} | user_headers
    ]

    http_opts =
      [
        timeout: :infinity,
        autoredirect: false,
        ssl: [
          verify: :verify_peer,
          cacertfile: CAStore.file_path(),
          depth: 3,
          customize_hostname_check: [
            {:match_fun, :public_key.pkix_verify_hostname_match_fun(:https)}
          ]
        ]
      ]
      |> Keyword.merge(Nerves.Utils.Proxy.config(url))
      |> Keyword.merge(Keyword.get(opts, :http_opts, []))

    {:ok, _} =
      :httpc.request(
        :get,
        {String.to_charlist(url), headers},
        http_opts,
        [stream: :self, receiver: self(), sync: false],
        :nerves
      )

    {:noreply, %{s | url: url, caller: from, get_opts: opts, progress?: progress?}}
  end

  @impl GenServer
  def handle_info({:http, {_ref, {:error, {:failed_connect, _}} = err}}, s) do
    GenServer.reply(s.caller, err)
  end

  def handle_info({:http, {_, :stream_start, headers}}, s) do
    content_length =
      case Enum.find(headers, fn {key, _} -> key == ~c"content-length" end) do
        nil ->
          0

        {_, content_length} ->
          {content_length, _} =
            content_length
            |> to_string()
            |> Integer.parse()

          content_length
      end

    filename =
      case Enum.find(headers, fn {key, _} -> key == ~c"content-disposition" end) do
        nil ->
          Path.basename(s.url)

        {_, filename} ->
          filename
          |> to_string
          |> String.split(";")
          |> List.last()
          |> String.trim()
          |> String.trim("filename=")
      end

    {:noreply, %{s | content_length: content_length, filename: filename}}
  end

  def handle_info({:http, {_, :stream, data}}, s) do
    size = byte_size(data) + s.buffer_size
    buffer = s.buffer <> data

    if progress?(s) do
      put_progress(size, s.content_length)
    end

    {:noreply, %{s | buffer_size: size, buffer: buffer}}
  end

  def handle_info({:http, {_, :stream_end, _headers}}, s) do
    if progress?(s) do
      IO.write(:stderr, "\n")
    end

    GenServer.reply(s.caller, {:ok, s.buffer})
    {:noreply, %{s | filename: "", content_length: 0, buffer: "", buffer_size: 0, url: nil}}
  end

  def handle_info({:http, {_ref, {{_, status_code, reason}, headers, _body}}}, s)
      when div(status_code, 100) == 3 do
    case Enum.find(headers, fn {key, _} -> key == ~c"location" end) do
      {~c"location", next_location} ->
        next_get_opts = Keyword.drop(s.get_opts, [:headers])

        handle_call({:get, List.to_string(next_location), next_get_opts}, s.caller, %{
          s
          | buffer: "",
            buffer_size: 0,
            number_of_redirects: s.number_of_redirects + 1
        })

      _ ->
        GenServer.reply(s.caller, {:error, format_error(status_code, reason)})
    end
  end

  def handle_info({:http, {_ref, {{_, status_code, reason}, _headers, _body}}}, s) do
    GenServer.reply(s.caller, {:error, format_error(status_code, reason)})
    {:noreply, s}
  end

  defp put_progress(size, max) do
    fraction = size / max
    completed = trunc(fraction * @progress_steps)
    percent = trunc(fraction * 100)
    unfilled = @progress_steps - completed

    IO.write(
      :stderr,
      "\r|#{String.duplicate("=", completed)}#{String.duplicate(" ", unfilled)}| #{percent}% (#{bytes_to_mb(size)} / #{bytes_to_mb(max)}) MB"
    )
  end

  defp format_error(status_code, reason) do
    "Status #{to_string(status_code)} #{to_string(reason)}"
  end

  defp start_httpc() do
    :inets.start(:httpc, profile: :nerves)

    opts = [
      max_sessions: 8,
      max_keep_alive_length: 4,
      max_pipeline_length: 4,
      keep_alive_timeout: 120_000,
      pipeline_timeout: 60_000
    ]

    :httpc.set_options(opts, :nerves)
  end

  defp bytes_to_mb(bytes) do
    trunc(bytes / 1024 / 1024)
  end

  defp progress?(%{progress?: progress?}) do
    System.get_env("NERVES_LOG_DISABLE_PROGRESS_BAR") == nil and progress?
  end

  defp tuple_to_charlist({k, v}) do
    {to_charlist(k), to_charlist(v)}
  end
end
