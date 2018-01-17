defmodule Mix.Nerves.Shell do
  def open(command, initial_input \\ []) do
    # We need to get raw binary access to the stdout file descriptor
    # so we can directly pass through control characters output by the command
    stdout_port = Port.open({:fd, 0, 1}, [:binary, :eof, :stream, :out])

    # We use the tty_sl driver for input because it handles tty geometry and
    # streaming mode.
    stdin_port = Port.open({:spawn, "tty_sl -c -e"}, [:binary, :eof, :stream, :in])

    # We run the command through the script command to emulate a pty
    cmd_port =
      Port.open({:spawn, "script -q /dev/null #{command}"}, [
        :binary,
        :eof,
        :stream,
        :stderr_to_stdout
      ])

    # Tell the script command about the terminal dimensions
    {w, h} = get_tty_geometry(stdin_port)

    Port.command(cmd_port, """
    stty sane rows #{h} cols #{w}; stty -echo
    export PS1=""; export PS2=""
    start() {
    echo -e "\\e[17F\\e[0J\\e[1;7m\n  Preparing Nerves Shell  \\e[0m"
    echo -e "\\e]0;Nerves Shell\\a"
    export PS1="\\e[1;7m Nerves \\e[0;1m \\w > \\e[0m"
    export PS2="\\e[1;7m Nerves \\e[0;1m \\w ..\\e[0m"
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

  @ctrl_op_get_winsize 100

  defp get_tty_geometry(tty_port) do
    geometry =
      :erlang.port_control(tty_port, @ctrl_op_get_winsize, [])
      |> :erlang.list_to_binary()

    <<w::native-integer-size(32), h::native-integer-size(32)>> = geometry
    {w, h}
  end
end
