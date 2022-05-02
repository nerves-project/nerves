defmodule Nerves.Utils.Stream do
  @moduledoc false
  use GenServer

  @timer 10_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def stop(pid) do
    GenServer.stop(pid)
  end

  def history(pid) do
    GenServer.call(pid, :history)
  end

  def init(opts) do
    file = opts[:file]
    history_lines = opts[:history_lines] || 100

    if file != nil do
      File.write(file, "", [:write])
    end

    {:ok,
     %{
       file: opts[:file],
       timer: Process.send_after(self(), :keep_alive, @timer),
       history: :queue.new(),
       history_lines: history_lines,
       history_saved: 0
     }}
  end

  def handle_call(:history, _from, s) do
    history =
      s.history
      |> :queue.to_list()
      |> Enum.join()

    {:reply, history, s}
  end

  def handle_info({:io_request, from, reply_as, {:put_chars, _encoding, chars}} = data, s) do
    if s.file != nil do
      File.write(s.file, chars, [:append])
    end

    s = save_history(s, chars)
    reply(from, reply_as, :ok)
    {:noreply, stdout(chars, data, s)}
  end

  def handle_info(:keep_alive, s) do
    IO.write(".")
    {:noreply, reset_timer(s)}
  end

  def stdout(<<">>>", tail::binary>>, _message, s), do: trim_write(">>>", "\n", tail, s)
  def stdout(<<"\e[7m>>>", tail::binary>>, _message, s), do: trim_write(">>>", "\e[7m", tail, s)

  def stdout(_, _, s), do: s

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
    Process.cancel_timer(s.timer)
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

  def reply(from, reply_as, reply) do
    send(from, {:io_reply, reply_as, reply})
  end
end
