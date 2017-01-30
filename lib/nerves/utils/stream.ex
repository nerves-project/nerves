defmodule Nerves.Utils.Stream do
  use GenServer

  @timer 10_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def stop(pid) do
    GenServer.stop(pid)
  end

  def init(opts) do
    file = opts[:file]
    if file != nil do
      File.write(file, "", [:write])
    end
    {:ok, %{
      file: opts[:file],
      timer: Process.send_after(self(), :keep_alive, @timer)
    }}
  end

  def handle_info({:io_request, from, reply_as, {:put_chars, _encoding, chars}} = data, s) do
    if s.file != nil do
      File.write(s.file, chars, [:append])
    end
    reply(from, reply_as, :ok)
    {:noreply, stdout(chars, data, s)}
  end

  def handle_info(:keep_alive, s) do
    IO.write "."
    {:noreply, reset_timer(s)}
  end

  def stdout(<<">>>", tail :: binary>>, _message, s),
    do: trim_write(">>>", "\n", tail, s)
  def stdout(<<"\e[7m>>>", tail :: binary>>, _message, s),
    do: trim_write(">>>", "\e[7m", tail, s)

  def stdout(_, _, s), do: s

  defp trim_write(trim, split, bin, s) do
    IO.write "\n"

    [bin | _] =
      bin
      |> String.split(trim)

    trim <> bin
    |> String.split(split)
    |> List.first
    |> String.strip
    |> IO.write
    reset_timer(s)
  end

  defp reset_timer(s) do
    Process.cancel_timer(s.timer)
    %{s | timer: Process.send_after(self(), :keep_alive, @timer)}
  end

  def reply(from, reply_as, reply) do
    send from, {:io_reply, reply_as, reply}
  end
end
