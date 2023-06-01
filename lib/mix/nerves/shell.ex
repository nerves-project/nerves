defmodule Mix.Nerves.Shell do
  @moduledoc false

  @doc """
  Open a shell with the Nerves environment set

  Used with build runners when compiling Nerves systems
  """
  @spec open(String.t(), [String.t()]) :: no_return()
  def open(command, initial_input \\ []) do
    # We need to get raw binary access to the stdout file descriptor
    # so we can directly pass through control characters output by the command
    stdout_port = Port.open({:fd, 0, 1}, [:binary, :eof, :stream, :out])

    # We use the tty_sl driver for input because it handles tty geometry and
    # streaming mode.
    stdin_port = Port.open({:spawn, "tty_sl -c -e"}, [:binary, :eof, :stream, :in])
    _ = Application.stop(:logger)
    # We run the command through the script command to emulate a pty
    cmd =
      "script -q /dev/null " <>
        case Nerves.Env.host_os() do
          "linux" ->
            "-c \"#{command}\""

          _ ->
            "#{command}"
        end

    cmd_port =
      Port.open({:spawn, cmd}, [
        :binary,
        :eof,
        :stream,
        :stderr_to_stdout,
        {:env,
         [
           {~c"PATH", Mix.Nerves.Utils.sanitize_path() |> to_charlist()},
           # Unset these Env vars which are set by the host Erlang
           # and might interfere with the build
           {~c"BINDIR", false},
           {~c"MIX_HOME", false},
           {~c"PROGNAME", false},
           {~c"ROOTDIR", false}
         ]}
      ])

    # Tell the script command about the terminal dimensions
    {w, h} = get_tty_geometry(stdin_port)

    Port.command(cmd_port, """
    stty sane rows #{h} cols #{w}; stty -echo
    export PS1=""; export PS2=""
    start() {
    echo -e "\\e[25F\\e[0J\\e[1;7m\n  Preparing Nerves Shell  \\e[0m"
    echo -e "\\e]0;Nerves Shell\\a"
    export PS1="\\e[1;7m Nerves \\e[0;1m \\W > \\e[0m"
    export PS2="\\e[1;7m Nerves \\e[0;1m \\W ..\\e[0m"
    #{Enum.join(initial_input, "\n")}
    stty echo
    }; start
    """)

    shell_loop(stdin_port, stdout_port, cmd_port)
  end

  defp shell_loop(stdin_port, stdout_port, cmd_port) do
    receive do
      # Route input from stdin to the command port
      {^stdin_port, {:data, data}} ->
        Port.command(cmd_port, data)
        shell_loop(stdin_port, stdout_port, cmd_port)

      # Route output from the command port to stdout
      {^cmd_port, {:data, data}} ->
        Port.command(stdout_port, data)
        shell_loop(stdin_port, stdout_port, cmd_port)

      # If any of the ports get closed, break out of the loop
      {_port, :eof} ->
        :ok

      # Ignore other messages
      _message ->
        shell_loop(stdin_port, stdout_port, cmd_port)
    end
  end

  # Starting in OTP 21.3.0, the CTRL_OP_GET_WINSIZE changes to be
  #
  # define(ERTS_TTYSL_DRV_CONTROL_MAGIC_NUMBER, 16#018b0900).
  # define(CTRL_OP_GET_WINSIZE, (100 + ?ERTS_TTYSL_DRV_CONTROL_MAGIC_NUMBER)).
  #
  # See https://github.com/erlang/otp/commit/ad5822c6b1401111bbdbc5e77fe097a3f1b2b3cb

  @erts_ttysl_drv_control_magic_number 0x018B0900
  @ctrl_op_get_winsize 100
  @ctrl_op_get_winsize_otp_21_3 @ctrl_op_get_winsize + @erts_ttysl_drv_control_magic_number

  defp get_tty_geometry(tty_port) do
    geometry =
      try do
        :erlang.port_control(tty_port, @ctrl_op_get_winsize, [])
      rescue
        _e in ArgumentError ->
          :erlang.port_control(tty_port, @ctrl_op_get_winsize_otp_21_3, [])
      end
      |> :erlang.list_to_binary()

    <<w::native-integer-size(32), h::native-integer-size(32)>> = geometry
    {w, h}
  end
end
