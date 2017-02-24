defmodule Nerves.Shell.Server do
  @moduledoc """
  The server is responsible for reading input and sending it to the evaluator.
  """

  def start(opts, {m, f, a}) do
    Process.flag(:trap_exit, true)
    {pid, ref} = spawn_monitor(m, f, a)
    start_loop(opts, pid, ref)
  end

  defp start_loop(opts, pid, ref) do
    receive do
      {:DOWN, ^ref, :process, ^pid, :normal} ->
        run(opts)
      {:DOWN, ^ref, :process, ^pid, other} ->
        IO.puts("#{__MODULE__} failed to start due to reason: #{inspect other}")
    end
  end

  defp run(opts) when is_list(opts) do
    IO.puts "Nerves Interactive Host Shell"
    evaluator = start_evaluator(opts)
    state = %{counter: 1, prefix: "host"}
    loop(state, evaluator, Process.monitor(evaluator))
  end

  defp loop(state, evaluator, evaluator_ref) do
    self_pid = self()
    counter = state.counter
    prefix = state.prefix

    input = spawn(fn -> io_get(self_pid, prefix, counter) end)
    wait_input(state, evaluator, evaluator_ref, input)
  end

  defp exit_loop(evaluator, evaluator_ref, done? \\ true) do
    Process.delete(:evaluator)
    Process.demonitor(evaluator_ref, [:flush])
    if done? do
      send(evaluator, {:done, self()})
    end
    :ok
  end

  defp io_get(pid, prefix, counter) do
    prompt = "#{prefix}[#{counter}]> "
    send(pid, {:input, self(), IO.gets(:stdio, prompt)})
  end

  defp wait_input(state, evaluator, evaluator_ref, input) do
    receive do
      {:input, ^input, command} when is_binary(command) ->
        send(evaluator, {:eval, self(), command, state})
        wait_eval(state, evaluator, evaluator_ref)
      {:input, ^input, {:error, :interrupted}} ->
        IO.puts("Interrupted")
        loop(state, evaluator, evaluator_ref)
      {:input, ^input, :eof} ->
        exit_loop(evaluator, evaluator_ref)
      {:input, ^input, {:error, :terminated}} ->
        exit_loop(evaluator, evaluator_ref)
    end
  end

  defp wait_eval(state, evaluator, evaluator_ref) do
    receive do
      {:evaled, ^evaluator, new_state} ->
        loop(new_state, evaluator, evaluator_ref)
      {:EXIT, _pid, :interrupt} ->
        # User did ^G while the evaluator was busy or stuck
        IO.puts("** (EXIT) interrupted")
        Process.delete(:evaluator)
        Process.exit(evaluator, :kill)
        Process.demonitor(evaluator_ref, [:flush])
        evaluator = start_evaluator([])
        loop(state, evaluator, Process.monitor(evaluator))
    end
  end

  def start_evaluator(opts) do
    self_pid = self()
    self_leader = Process.group_leader
    evaluator = opts[:evaluator] || :proc_lib.start(Nerves.Shell.Evaluator, :init, [:ack, self_pid, self_leader, opts])
    evaluator
  end
end

