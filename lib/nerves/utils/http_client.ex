defmodule Nerves.Utils.HTTPClient do
  use GenServer

  @timeout 120_000
  @progress_steps 50

  def start_link() do
    {:ok, _} = Application.ensure_all_started(:nerves)
    start_httpc()
    GenServer.start_link(__MODULE__, [])
  end

  def stop(pid) do
    GenServer.stop(pid)
  end

  def get(pid, url) do
    GenServer.call(pid, {:get, url}, @timeout)
  end

  def init([]) do
    {:ok, %{
      url: nil,
      content_length: 0,
      buffer: "",
      buffer_size: 0,
      filename: "",
      caller: nil
    }}
  end

  def handle_call({:get, url}, from, s) do
    url = String.to_char_list(url)
    headers = [
      {'Content-Type', 'application/octet-stream'}
    ]

    http_opts = [timeout: @timeout, autoredirect: true] ++ Nerves.Utils.Proxy.config(url)
    opts = [stream: :self, receiver: self(), sync: false]
    :httpc.request(:get, {url, headers}, http_opts, opts, :nerves)
    {:noreply, %{s | url: url, caller: from}}
  end

  def handle_info({:http, {_, :stream_start, headers}}, s) do
    {_, content_length} =
      headers
      |> Enum.find(fn({key, _}) -> key == 'content-length' end)

    {content_length, _} =
      content_length
      |> to_string()
      |> Integer.parse()

    {_, filename} =
      headers
      |> Enum.find(fn({key, _}) -> key == 'content-disposition' end)
    filename =
      filename
      |> to_string
      |> String.split(";")
      |> List.last
      |> String.strip
      |> String.trim("filename=")
    {:noreply, %{s | content_length: content_length, filename: filename}}
  end

  def handle_info({:http, {_, :stream, data}}, s) do
    size = byte_size(data) + s.buffer_size
    buffer = s.buffer <> data
    put_progress(size, s.content_length)
    {:noreply, %{s | buffer_size: size, buffer: buffer}}
  end

  def handle_info({:http, {_, :stream_end, _headers}}, s) do
    IO.write(:stderr, "\n")
    GenServer.reply(s.caller, {:ok, s.buffer})
    {:noreply, %{s | filename: "", content_length: 0, buffer: "", buffer_size: 0, url: nil}}
  end

  def put_progress(size, max) do
    fraction = (size / max)
    completed = trunc(fraction * @progress_steps)
    percent = trunc(fraction * 100)
    unfilled = @progress_steps - completed
    IO.write(:stderr, "\r|#{String.duplicate("=", completed)}#{String.duplicate(" ", unfilled)}| #{percent}% (#{bytes_to_mb(size)} / #{bytes_to_mb(max)}) MB")
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
end
