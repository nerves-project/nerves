defmodule CoverHelper do
  @moduledoc false

  @doc """
  Helper to run mix with code coverage if coverage is being tracked
  """
  def mix(["deps.get" | _] = args, opts) do
    # Exporting coverage when getting dependencies doesn't work, so short circuit
    # it to just run the command.
    run_mix(args, opts)
  end

  def mix(args, opts) do
    run_mix(mix_args(args, opts), opts)
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
    script_args = mix_args(args, opts) |> to_script_args()

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
          env: port_env(Keyword.get(opts, :env, []))
        ]
      )

    interact(port, interactions, "", "", timeout)
  end

  defp to_script_args(args) do
    case :os.type() do
      {:unix, :linux} -> ["-e", "-c", Enum.join(["mix" | args], " "), "-q", "/dev/null"]
      {:unix, _bsd} -> ["-eq", "/dev/null", "mix" | args]
    end
  end

  defp run_mix(args, opts) do
    final_opts = Keyword.merge([stderr_to_stdout: true, into: IO.stream()], opts)
    System.cmd("mix", args, final_opts)
  end

  defp mix_args(["deps.get" | _] = args, _opts), do: args

  defp mix_args(args, opts) do
    if :cover.modules() != [],
      do: ["cover", File.cwd!(), cover_export_name(args, opts)] ++ args,
      else: args
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

    if File.exists?(path) do
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
