defmodule Nerves.Host.Evaluator do
  @moduledoc """
  The evaluator is responsible for managing the shell port and executing commands against it.
  """

  def init(command, server, leader, _opts) do
    old_leader = Process.group_leader
    Process.group_leader(self(), leader)

    command == :ack && :proc_lib.init_ack(self())

    path = System.find_executable("sh")
    port = Port.open({:spawn_executable, path}, [:binary, :stderr_to_stdout, :eof, :exit_status])
    state = %{port: port, path: path}

    try do
      loop(server, state)
    after
      Process.group_leader(self(), old_leader)
    end
  end

  defp loop(server, state) do
    port = state.port
    receive do
      {^port, {:data, data}} ->
        IO.puts("\n#{data}")
        loop(server, state)
      {^port, {:exit_status, status}} ->
        IO.puts("Interactive shell port exited with status #{status}")
        :ok
      {:eval, ^server, command, shell_state} ->
        new_shell_state = %{shell_state | counter: shell_state.counter + 1}
        send(state.port, {self(), {:command, command}})
        send(server, {:evaled, self(), new_shell_state})
        loop(server, state)
      {:done, ^server} ->
        send(port, {self(), :close})
        :ok
      other ->
        IO.inspect(other, label: "Unknown message received by Nerves host command evaluator")
        loop(server, state)
    end
  end
end
