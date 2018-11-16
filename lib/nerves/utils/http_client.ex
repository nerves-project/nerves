defmodule Nerves.Utils.HTTPClient do
  use GenServer

  @progress_steps 50
  @redirect_status_codes [301, 302, 303, 307, 308]

  def start_link() do
    {:ok, _} = Application.ensure_all_started(:nerves)
    start_httpc()
    GenServer.start_link(__MODULE__, [])
  end

  def stop(pid) do
    GenServer.stop(pid)
  end

  def get(_, _, _ \\ [])

  def get(_pid, %URI{host: nil, path: path}, _opts) do
    path
    |> Path.expand()
    |> File.read()
  end

  def get(pid, %URI{} = uri, opts) do
    url =
      uri
      |> URI.to_string()
      |> URI.encode()
      |> String.replace("+", "%2B")

    get(pid, url, opts)
  end

  def get(pid, url, opts), do: GenServer.call(pid, {:get, url, opts}, :infinity)

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
       opts: []
     }}
  end

  def handle_call({:get, _url, _opts}, _from, %{number_of_redirects: n} = s) when n > 5 do
    GenServer.reply(s.caller, {:error, :too_many_redirects})
    {:noreply, %{s | url: nil, number_of_redirects: 0, caller: nil}}
  end

  def handle_call({:get, url, opts}, from, s) do
    progress? = Keyword.get(opts, :progress?, true)

    headers =
      Keyword.get(opts, :headers, [])
      |> Enum.map(fn {k, v} ->
        {to_charlist(k), to_charlist(v)}
      end)

    headers = [
      {'User-Agent', 'Nerves HTTP Client #{Nerves.version()}'},
      {'Content-Type', 'application/octet-stream'} | headers
    ]

    http_opts =
      [timeout: :infinity, autoredirect: false]
      |> Keyword.merge(Nerves.Utils.Proxy.config(url))
      |> Keyword.merge(Keyword.get(opts, :http_opts, []))

    opts = [stream: :self, receiver: self(), sync: false]
    :httpc.request(:get, {String.to_charlist(url), headers}, http_opts, opts, :nerves)
    {:noreply, %{s | url: url, caller: from, opts: opts, progress?: progress?}}
  end

  def handle_info({:http, {_, :stream_start, headers}}, s) do
    content_length =
      case Enum.find(headers, fn {key, _} -> key == 'content-length' end) do
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
      case Enum.find(headers, fn {key, _} -> key == 'content-disposition' end) do
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
      when status_code in @redirect_status_codes do
    case Enum.find(headers, fn {key, _} -> key == 'location' end) do
      {'location', next_location} ->
        handle_call({:get, List.to_string(next_location), headers: headers}, s.caller, %{
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

  def put_progress(size, max) do
    fraction = size / max
    completed = trunc(fraction * @progress_steps)
    percent = trunc(fraction * 100)
    unfilled = @progress_steps - completed

    IO.write(
      :stderr,
      "\r|#{String.duplicate("=", completed)}#{String.duplicate(" ", unfilled)}| #{percent}% (#{
        bytes_to_mb(size)
      } / #{bytes_to_mb(max)}) MB"
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
end
