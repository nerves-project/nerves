# SPDX-FileCopyrightText: 2026 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule CoverHelper do
  @moduledoc false

  @doc """
  Helper to run mix with code coverage if coverage is being tracked
  """

  def mix(args, opts) do
    {command, command_args, env} = mix_command(args, opts)
    new_env = Keyword.get(opts, :env, []) ++ env
    new_opts = Keyword.put(opts, :env, new_env)
    run_mix(command, command_args, task_name(args), new_opts)
  end

  @doc """
  Runs mix under a pseudo-terminal and performs the requested interactions

  This provides a very simple expect-like interaction with the mix task
  being run. The interactions is a list of tuples with the following form:

  * `{:wait, regex}` - wait for text matching the regex
  * `{:write, text}` - write the specified text

  Each `{:wait, regex}` must match the command's output before the next
  interaction is performed. Returns `{:error, :timeout, output}` if a wait
  exceeds `:timeout`, which defaults to 30 seconds.
  """
  @spec interactive_mix([String.t()], [{:wait, Regex.t()} | {:write, iodata()}], keyword()) ::
          {:ok, String.t(), non_neg_integer()}
          | {:error, :timeout | {:exited, non_neg_integer()}, String.t()}
  def interactive_mix(args, interactions, opts) do
    script = System.find_executable("script") || raise "Could not find the script utility"
    timeout = Keyword.get(opts, :timeout, :timer.seconds(30))
    {command, command_args, script_env} = mix_command(args, opts)
    script_args = to_script_args(command, command_args)

    port =
      Port.open(
        {:spawn_executable, script},
        [
          :binary,
          :exit_status,
          :use_stdio,
          :stderr_to_stdout,
          args: script_args,
          cd: String.to_charlist(Keyword.fetch!(opts, :cd)),
          env: port_env(Keyword.get(opts, :env, []) ++ script_env)
        ]
      )

    interact(port, interactions, "", "", timeout)
  end

  defp to_script_args(command, args) do
    case :os.type() do
      {:unix, :linux} ->
        command_line =
          Enum.map_join([command | args], " ", fn arg ->
            "'" <> String.replace(arg, "'", "'\\''") <> "'"
          end)

        ["-e", "-c", command_line, "-q", "/dev/null"]

      {:unix, _bsd} ->
        ["-eq", "/dev/null", command | args]
    end
  end

  defp run_mix(command, args, task, opts) do
    if Keyword.has_key?(opts, :into) do
      System.cmd(command, args, Keyword.put_new(opts, :stderr_to_stdout, true))
    else
      {:ok, output_buffer} = CoverHelper.OutputBuffer.start_link(task)

      final_opts =
        Keyword.merge(
          [stderr_to_stdout: true, into: CoverHelper.OutputBuffer.stream(output_buffer)],
          opts
        )

      {_, exit_status} =
        System.cmd(command, args, final_opts)

      if exit_status == 0 do
        CoverHelper.OutputBuffer.clear_status(output_buffer)
      else
        CoverHelper.OutputBuffer.dump(output_buffer)
      end

      :ok = GenServer.stop(output_buffer)
      {"", exit_status}
    end
  end

  defp task_name([task | _]), do: task

  defp mix_command(args, opts) do
    case mix_env(args, opts) do
      [] ->
        {"mix", args, []}

      env ->
        startup = Path.expand("../priv/coverage_startup.exs", __DIR__)
        {"elixir", ["-r", startup, "-S", "mix" | args], env}
    end
  end

  defp mix_env(["deps.get" | _], _opts), do: []

  defp mix_env(args, opts) do
    if :cover.modules() != [],
      do: [{"COVER_PATH", File.cwd!()}, {"COVER_EXPORT", cover_export_name(args, opts)}],
      else: []
  end

  defp port_env(env) do
    for {key, value} <- env, do: {String.to_charlist(key), String.to_charlist(value)}
  end

  defp interact(port, [{:write, text} | interactions], output, buffer, timeout) do
    true = Port.command(port, IO.iodata_to_binary(text))
    interact(port, interactions, output, buffer, timeout)
  end

  defp interact(port, [{:wait, regex} | interactions], output, buffer, timeout) do
    if Regex.match?(regex, buffer) do
      [_, buffer] = Regex.split(regex, buffer, parts: 2)
      interact(port, interactions, output, buffer, timeout)
    else
      receive do
        {^port, {:data, data}} ->
          interact(port, [{:wait, regex} | interactions], output <> data, buffer <> data, timeout)

        {^port, {:exit_status, exit_status}} ->
          {:error, {:exited, exit_status}, output}
      after
        timeout ->
          Port.close(port)
          {:error, :timeout, output}
      end
    end
  end

  defp interact(port, [], output, _buffer, timeout) do
    receive do
      {^port, {:data, data}} ->
        interact(port, [], output <> data, "", timeout)

      {^port, {:exit_status, exit_status}} ->
        {:ok, output, exit_status}
    after
      timeout ->
        Port.close(port)
        {:error, :timeout, output}
    end
  end

  defp cover_export_name([task | _], opts) do
    path = Path.basename(opts[:cd] || File.cwd!())

    unique_path("#{path}_#{target(opts)}_#{task}", 0)
  end

  defp unique_path(base, counter) do
    path = base <> "_#{counter}"

    if File.exists?(Path.join("cover", path <> ".coverdata")) do
      unique_path(base, counter + 1)
    else
      path
    end
  end

  defp target(opts) do
    env = Keyword.get(opts, :env, [])
    Enum.find_value(env, "host", fn {k, v} -> if k == "MIX_TARGET", do: v end)
  end
end
