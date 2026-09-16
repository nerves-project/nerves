# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule CoverHelper.OutputBuffer do
  @moduledoc false
  use GenServer

  @buffer_size 100
  @status_interval :timer.seconds(1)

  defmodule Stream do
    @moduledoc false
    defstruct [:pid]
  end

  @spec start_link(String.t()) :: GenServer.on_start()
  def start_link(task), do: GenServer.start_link(__MODULE__, task)

  @spec stream(pid()) :: Stream.t()
  def stream(pid), do: %Stream{pid: pid}

  @spec write(pid(), iodata()) :: :ok
  def write(pid, data), do: GenServer.cast(pid, {:write, IO.iodata_to_binary(data)})

  @spec clear_status(pid()) :: :ok
  def clear_status(pid), do: GenServer.call(pid, :clear_status)

  @spec dump(pid()) :: :ok
  def dump(pid), do: GenServer.call(pid, :dump)

  @impl GenServer
  def init(task) do
    interactive? = interactive_terminal?()

    if interactive? do
      Process.send_after(self(), :status, @status_interval)
    end

    {:ok,
     %{
       buffer: CircularBuffer.new(@buffer_size),
       bytes: 0,
       interactive?: interactive?,
       pending: "",
       started_at: System.monotonic_time(:second),
       task: task,
       status_visible?: false
     }}
  end

  @impl GenServer
  def handle_cast({:write, data}, state) do
    {buffer, pending} = add_lines(state.buffer, state.pending <> data)
    {:noreply, %{state | buffer: buffer, bytes: state.bytes + byte_size(data), pending: pending}}
  end

  @impl GenServer
  def handle_call(:clear_status, _from, state) do
    {:reply, :ok, clear_display_status(state)}
  end

  def handle_call(:dump, _from, state) do
    state
    |> finish_pending()
    |> clear_display_status()
    |> dump_lines()

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_info(:status, %{interactive?: true} = state) do
    elapsed = System.monotonic_time(:second) - state.started_at
    IO.write("\r#{IO.ANSI.clear_line()}[mix #{state.task}|#{elapsed}s,#{state.bytes}B]")
    Process.send_after(self(), :status, @status_interval)
    {:noreply, %{state | status_visible?: true}}
  end

  defp add_lines(buffer, output) do
    [pending | lines] = output |> String.split("\n", trim: false) |> Enum.reverse()

    buffer =
      lines
      |> Enum.reverse()
      |> Enum.reduce(buffer, fn line, buffer ->
        CircularBuffer.insert(buffer, String.trim_trailing(line, "\r"))
      end)

    {buffer, pending}
  end

  defp finish_pending(%{pending: ""} = state), do: state

  defp finish_pending(state) do
    buffer =
      CircularBuffer.insert(state.buffer, String.trim_trailing(state.pending, "\r"))

    %{state | buffer: buffer, pending: ""}
  end

  defp clear_display_status(%{interactive?: true, status_visible?: true} = state) do
    IO.write("\r#{IO.ANSI.clear_line()}\r")
    %{state | status_visible?: false}
  end

  defp clear_display_status(state), do: state

  defp dump_lines(state) do
    lines = Enum.to_list(state.buffer)

    IO.puts(:stderr, "\nLast #{length(lines)} lines of mix output:")
    Enum.each(lines, &IO.puts(:stderr, &1))
  end

  defp interactive_terminal?() do
    # There's no Erlang isatty() call for checking for an interactive terminal,
    # but it can be inferred from whether Erlang knows the terminal size.
    case :io.columns() do
      {:ok, _cols} -> true
      _ -> false
    end
  end
end

defimpl Collectable, for: CoverHelper.OutputBuffer.Stream do
  def into(stream) do
    {stream,
     fn
       stream, {:cont, data} ->
         CoverHelper.OutputBuffer.write(stream.pid, data)
         stream

       _stream, :done ->
         :ok

       _stream, :halt ->
         :ok
     end}
  end
end
