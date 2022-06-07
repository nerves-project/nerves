defmodule Nerves.Utils.Stream do
  @moduledoc false
  use GenServer

  @timer 10_000

  @type options() :: [file: Path.t(), history_lines: non_neg_integer()]
  @type state() :: %{
          file: String.t() | nil,
          timer: reference(),
          history: :queue.queue(),
          history_lines: non_neg_integer,
          history_saved: non_neg_integer
        }

  @spec start_link(options()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @spec stop(GenServer.server()) :: :ok
  def stop(pid) do
    GenServer.stop(pid)
  end

  @spec history(GenServer.server()) :: String.t()
  def history(pid) do
    GenServer.call(pid, :history)
  end

  @impl GenServer
  def init(opts) do
    file = opts[:file]
    history_lines = opts[:history_lines] || 100

    _ = if file != nil, do: File.write(file, "", [:write])

    {:ok,
     %{
       file: file,
       timer: Process.send_after(self(), :keep_alive, @timer),
       history: :queue.new(),
       history_lines: history_lines,
       history_saved: 0
     }}
  end

  @impl GenServer
  def handle_call(:history, _from, s) do
    history =
      s.history
      |> :queue.to_list()
      |> Enum.join()

    {:reply, history, s}
  end

  @impl GenServer
  def handle_info({:io_request, from, reply_as, {:put_chars, _encoding, chars}}, s) do
    _ = if s.file != nil, do: File.write(s.file, chars, [:append])

    s = save_history(s, chars)
    reply(from, reply_as, :ok)
    {:noreply, stdout(chars, s)}
  end

  @impl GenServer
  def handle_info(:keep_alive, s) do
    IO.write(".")
    {:noreply, reset_timer(s)}
  end

  def handle_info(_, s) do
    {:noreply, s}
  end

  @spec stdout(String.t(), state()) :: state()
  def stdout(<<">>>", tail::binary>>, s), do: trim_write(">>>", "\n", tail, s)
  def stdout(<<"\e[7m>>>", tail::binary>>, s), do: trim_write(">>>", "\e[7m", tail, s)
  def stdout(_, s), do: s

  defp trim_write(trim, split, bin, s) do
    IO.write("\n")

    [bin | _] =
      bin
      |> String.split(trim)

    (trim <> bin)
    |> String.split(split)
    |> List.first()
    |> String.trim()
    |> IO.write()

    reset_timer(s)
  end

  defp reset_timer(s) do
    _ = Process.cancel_timer(s.timer)
    %{s | timer: Process.send_after(self(), :keep_alive, @timer)}
  end

  defp save_history(%{history_saved: lines, history_lines: lines} = s, line) do
    history = :queue.in(line, s.history)
    {_, history} = :queue.out(history)
    %{s | history: history}
  end

  defp save_history(s, line) do
    history = :queue.in(line, s.history)
    %{s | history: history, history_saved: s.history_saved + 1}
  end

  defp reply(from, reply_as, reply) do
    send(from, {:io_reply, reply_as, reply})
  end
end
