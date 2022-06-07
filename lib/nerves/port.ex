defmodule Nerves.Port do
  @moduledoc """
  The code from this file was copied in from MuonTrap
  https://github.com/fhunleth/muontrap
  """

  @spec exec_path() :: String.t()
  def exec_path() do
    Application.app_dir(:nerves, ["priv", "port"])
  end

  @doc """
  Run a command in a similar way to System.cmd/3.
  """
  @spec cmd(binary(), [binary()], keyword()) ::
          {Collectable.t(), exit_status :: non_neg_integer()}
  def cmd(command, args, opts \\ []) when is_binary(command) and is_list(args) do
    exec_path()
    |> File.exists?()
    |> do_cmd(command, args, opts)
  end

  # Port process was compiled
  defp do_cmd(true, command, args, opts) do
    options = validate(command, args, opts)
    opts = port_options(options)
    {initial, fun} = Collectable.into(options.into)

    try do
      do_port_cmd(Port.open({:spawn_executable, to_charlist(exec_path())}, opts), initial, fun)
    catch
      kind, reason ->
        fun.(initial, :halt)
        :erlang.raise(kind, reason, __STACKTRACE__)
    else
      {acc, status} -> {fun.(acc, :done), status}
    end
  end

  # Port process was not compiled, fail back to System.cmd/3
  defp do_cmd(false, command, args, opts) do
    System.cmd(command, args, opts)
  end

  defp do_port_cmd(port, acc, fun) do
    receive do
      {^port, {:data, data}} ->
        do_port_cmd(port, fun.(acc, {:cont, data}), fun)

      {^port, {:exit_status, status}} ->
        {acc, status}
    end
  end

  defp port_options(options) do
    [
      :use_stdio,
      :exit_status,
      :binary,
      :hide,
      {:args, nerves_args(options)} | Enum.flat_map(options, &port_option/1)
    ]
  end

  defp nerves_args(options) do
    Enum.flat_map(options, &nerves_arg/1) ++ ["--", options.cmd] ++ options.args
  end

  defp nerves_arg({:delay_to_sigkill, delay}), do: ["--delay-to-sigkill", to_string(delay)]
  defp nerves_arg({:arg0, arg0}), do: ["--arg0", arg0]
  defp nerves_arg(_other), do: []

  defp port_option({:stderr_to_stdout, true}), do: [:stderr_to_stdout]
  defp port_option({:env, env}), do: [{:env, env}]

  defp port_option({:cd, bin}), do: [{:cd, bin}]
  defp port_option({:arg0, bin}), do: [{:arg0, bin}]
  defp port_option({:parallelism, bool}), do: [{:parallelism, bool}]
  defp port_option(_other), do: []

  defp validate(cmd, args, opts) do
    assert_no_null_byte!(cmd)

    unless Enum.all?(args, &is_binary/1) do
      raise ArgumentError, "all arguments for Nerves.Port.cmd/3 must be binaries"
    end

    abs_command = System.find_executable(cmd) || :erlang.error(:enoent, [cmd, args, opts])

    validate_options(abs_command, args, opts)
  end

  defp validate_options(cmd, args, opts) do
    Enum.reduce(
      opts,
      %{cmd: cmd, args: args, into: ""},
      &validate_option/2
    )
  end

  # System.cmd/3 options
  defp validate_option({:into, what}, opts), do: Map.put(opts, :into, what)
  defp validate_option({:cd, bin}, opts) when is_binary(bin), do: Map.put(opts, :cd, bin)

  defp validate_option({:arg0, bin}, opts) when is_binary(bin),
    do: Map.put(opts, :arg0, bin)

  defp validate_option({:stderr_to_stdout, bool}, opts) when is_boolean(bool),
    do: Map.put(opts, :stderr_to_stdout, bool)

  defp validate_option({:parallelism, bool}, opts) when is_boolean(bool),
    do: Map.put(opts, :parallelism, bool)

  defp validate_option({:env, enum}, opts),
    do: Map.put(opts, :env, validate_env(enum))

  defp validate_option({:delay_to_sigkill, delay}, opts) when is_integer(delay),
    do: Map.put(opts, :delay_to_sigkill, delay)

  defp validate_option({key, val}, _opts),
    do: raise(ArgumentError, "invalid option #{inspect(key)} with value #{inspect(val)}")

  defp validate_env(enum) do
    Enum.map(enum, fn
      {k, nil} ->
        {String.to_charlist(k), false}

      {k, v} ->
        {String.to_charlist(k), String.to_charlist(v)}

      other ->
        raise ArgumentError, "invalid environment key-value #{inspect(other)}"
    end)
  end

  # Copied from Elixir's system.ex to make Nerves.Port.cmd pass System.cmd's tests
  defp assert_no_null_byte!(binary) do
    case :binary.match(binary, "\0") do
      {_, _} ->
        raise ArgumentError,
              "cannot execute Nerves.Port.cmd/3 for program with null byte, got: #{inspect(binary)}"

      :nomatch ->
        :ok
    end
  end
end
