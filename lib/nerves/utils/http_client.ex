# SPDX-FileCopyrightText: 2016 Justin Schneck
# SPDX-FileCopyrightText: 2018 Michael Schmidt
# SPDX-FileCopyrightText: 2020 Tomasz Kazimierz Motyl
# SPDX-FileCopyrightText: 2021 Frank Hunleth
# SPDX-FileCopyrightText: 2021 Jon Carstens
# SPDX-FileCopyrightText: 2021 Jon Thacker
# SPDX-FileCopyrightText: 2022 Martin Wagner
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Nerves.Utils.HTTPClient do
  @moduledoc false

  alias Nerves.Utils.Proxy

  @progress_steps 50
  @max_redirects 5

  @type opts :: [
          into: Collectable.t(),
          progress?: boolean(),
          headers: [{String.t() | charlist(), String.t() | charlist()}]
        ]

  @type request_state :: %{
          collector: (term(), Collectable.command() -> term()),
          collector_acc: term(),
          content_length: non_neg_integer(),
          get_opts: opts(),
          progress?: boolean(),
          received: non_neg_integer(),
          redirects: non_neg_integer()
        }

  @doc """
  Make an HTTP GET request and collect the response body.

  The `:into` option accepts any `Collectable.t()`. Defaults to `""` which
  collects the response into a string. Pass a `File.Stream` to write directly
  to a file.

  Returns `{:ok, collected}` or `{:error, reason}`.
  """
  @spec get(URI.t() | String.t(), opts()) ::
          {:ok, Collectable.t()} | {:error, String.t() | :too_many_redirects | atom()}
  def get(url_or_uri, opts \\ [])

  def get(%URI{host: nil, path: path}, opts) do
    into = Keyword.get(opts, :into, "")

    case File.read(Path.expand(path)) do
      {:ok, data} ->
        {acc, collector} = Collectable.into(into)
        acc = collector.(acc, {:cont, data})
        {:ok, collector.(acc, :done)}

      {:error, _} = error ->
        error
    end
  end

  def get(%URI{} = uri, opts) do
    uri
    |> URI.to_string()
    |> get(opts)
  end

  def get(url, opts) do
    _ = Keyword.validate!(opts, [:headers, :into, :progress?])
    start_httpc()

    url
    |> start_request(opts, 0)
    |> await_response()
  end

  defp start_request(_url, _opts, redirects) when redirects > @max_redirects do
    {:done, {:error, :too_many_redirects}}
  end

  defp start_request(url, opts, redirects) do
    progress? =
      Keyword.get(opts, :progress?, true) and progress_enabled?() and interactive_terminal?()

    into = Keyword.get(opts, :into, "")
    {acc, collector} = Collectable.into(into)

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
      |> Keyword.merge(Proxy.request_options(url))

    {:ok, request_ref} =
      :httpc.request(
        :get,
        {String.to_charlist(url), headers},
        http_opts,
        [stream: :self, receiver: self(), sync: false],
        :nerves
      )

    {:await, request_ref,
     %{
       collector: collector,
       collector_acc: acc,
       content_length: 0,
       get_opts: opts,
       progress?: progress?,
       received: 0,
       redirects: redirects
     }}
  end

  defp await_response({:done, result}), do: result

  defp await_response({:await, request_ref, state}) do
    receive do
      {:http, {^request_ref, {:error, {:failed_connect, _}} = err}} ->
        err

      {:http, {^request_ref, :stream_start, headers}} ->
        await_response({:await, request_ref, %{state | content_length: content_length(headers)}})

      {:http, {^request_ref, :stream, data}} ->
        size = byte_size(data) + state.received
        acc = state.collector.(state.collector_acc, {:cont, data})
        put_progress(state, size)
        await_response({:await, request_ref, %{state | received: size, collector_acc: acc}})

      {:http, {^request_ref, :stream_end, _headers}} ->
        progress_done(state)
        {:ok, state.collector.(state.collector_acc, :done)}

      {:http, {^request_ref, {{_, status_code, reason}, headers, _body}}}
      when div(status_code, 100) == 3 ->
        state.collector.(state.collector_acc, :halt)

        case Enum.find(headers, fn {key, _} -> key == ~c"location" end) do
          {~c"location", next_location} ->
            next_get_opts = Keyword.drop(state.get_opts, [:headers])

            next_location
            |> List.to_string()
            |> start_request(next_get_opts, state.redirects + 1)
            |> await_response()

          _ ->
            {:error, format_error(status_code, reason)}
        end

      {:http, {^request_ref, {{_, status_code, reason}, _headers, _body}}} ->
        state.collector.(state.collector_acc, :halt)
        {:error, format_error(status_code, reason)}
    end
  end

  defp content_length(headers) do
    case Enum.find(headers, fn {key, _} -> key == ~c"content-length" end) do
      nil ->
        0

      {_, header_value} ->
        {content_length, _} =
          header_value
          |> to_string()
          |> Integer.parse()

        content_length
    end
  end

  defp format_error(status_code, reason) do
    "Status #{to_string(status_code)} #{to_string(reason)}"
  end

  defp start_httpc() do
    _ = :inets.start(:httpc, profile: :nerves)

    opts =
      [
        max_sessions: 8,
        max_keep_alive_length: 4,
        max_pipeline_length: 4,
        keep_alive_timeout: 120_000,
        pipeline_timeout: 60_000
      ] ++ Proxy.httpc_options()

    :ok = :httpc.set_options(opts, :nerves)
  end

  defp progress_enabled?() do
    System.get_env("NERVES_LOG_DISABLE_PROGRESS_BAR") == nil
  end

  defp interactive_terminal?() do
    # There's no Erlang isatty() call for checking for an interactive terminal,
    # but it can be inferred from whether Erlang knows the terminal size.
    case :io.columns() do
      {:ok, _cols} -> true
      _ -> false
    end
  end

  defp put_progress(%{progress?: true} = state, size) do
    max = state.content_length
    fraction = size / max
    completed = trunc(fraction * @progress_steps)
    percent = trunc(fraction * 100)
    unfilled = @progress_steps - completed

    IO.write(
      :stderr,
      "\r|#{String.duplicate("=", completed)}#{String.duplicate(" ", unfilled)}| #{percent}% (#{bytes_to_mb(size)} / #{bytes_to_mb(max)}) MB"
    )
  end

  defp put_progress(_state, _size), do: :ok

  defp progress_done(%{progress?: true} = _state), do: IO.write(:stderr, "\n")
  defp progress_done(_state), do: :ok

  defp bytes_to_mb(bytes) do
    trunc(bytes / 1024 / 1024)
  end

  defp tuple_to_charlist({k, v}) do
    {to_charlist(k), to_charlist(v)}
  end
end
