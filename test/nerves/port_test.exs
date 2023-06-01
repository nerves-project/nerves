defmodule Nerves.PortTest do
  use NervesTest.Case

  defp run_port(args) do
    # Directly invoke the port to reduce the amount of code
    # to debug if something breaks.
    port =
      Port.open(
        {:spawn_executable, Nerves.Port.exec_path()},
        args: args
      )

    # The port starts asynchronously. If the test needs to register
    # a signal handler, this is problematic since we can beat it.
    # The right answer is to handshake with our test helper app.
    # Since that's work, sleep briefly.
    Process.sleep(10)
    port
  end

  test "closing the port kills the process" do
    port = run_port(["./test/fixtures/port/do_nothing.test"])

    os_pid = os_pid(port)
    assert os_process_alive?(os_pid)

    Port.close(port)

    wait_for_close_check()
    refute os_process_alive?(os_pid)
  end

  test "closing the port kills a process that ignores sigterm" do
    port = run_port(["--delay-to-sigkill", "1", "test/fixtures/port/ignore_sigterm.test"])

    os_pid = os_pid(port)
    assert os_process_alive?(os_pid)
    Port.close(port)

    wait_for_close_check()
    refute os_process_alive?(os_pid)
  end

  test "delaying the SIGKILL" do
    port = run_port(["--delay-to-sigkill", "250", "test/fixtures/port/ignore_sigterm.test"])

    Process.sleep(10)
    os_pid = os_pid(port)
    assert os_process_alive?(os_pid)
    Port.close(port)

    Process.sleep(100)
    # process should be around for 250ms, so it should be around here.
    assert os_process_alive?(os_pid)

    Process.sleep(200)

    # Now it should be gone
    refute os_process_alive?(os_pid)
  end

  # The following tests are copied from System.cmd to help ensure that
  # Nerves.Port.cmd/3 works similarly.
  test "cmd/2 raises for null bytes" do
    assert_raise ArgumentError,
                 ~r"cannot execute Nerves.Port.cmd/3 for program with null byte",
                 fn ->
                   Nerves.Port.cmd("null\0byte", [])
                 end
  end

  test "cmd/3 raises with non-binary arguments" do
    assert_raise ArgumentError, ~r"all arguments for Nerves.Port.cmd/3 must be binaries", fn ->
      Nerves.Port.cmd("ls", [~c"/usr"])
    end
  end

  test "cmd/2" do
    assert {"hello\n", 0} = Nerves.Port.cmd("echo", ["hello"])
  end

  test "cmd/3 (with options)" do
    opts = [
      into: [],
      cd: File.cwd!(),
      env: %{"foo" => "bar", "baz" => nil},
      arg0: "echo",
      stderr_to_stdout: true,
      parallelism: true
    ]

    assert {["hello\n"], 0} = Nerves.Port.cmd("echo", ["hello"], opts)
  end

  # Test adapted from https://github.com/elixir-lang/elixir/blob/v1.15.0/lib/elixir/test/elixir/system_test.exs#L121
  @echo "echo-elixir-test"
  @tag :tmp_dir
  test "cmd/2 with absolute and relative paths", config do
    echo = Path.join(config.tmp_dir, @echo)
    File.mkdir_p!(Path.dirname(echo))
    File.ln_s!(System.find_executable("echo"), echo)

    File.cd!(Path.dirname(echo), fn ->
      # There is a bug in OTP where find_executable is finding
      # entries on the current directory. If this is the case,
      # we should avoid the assertion below.
      unless System.find_executable(@echo) do
        assert :enoent = catch_error(Nerves.Port.cmd(@echo, ["hello"]))
      end

      assert {"hello\n", 0} =
               Nerves.Port.cmd(Path.join(File.cwd!(), @echo), ["hello"], [{:arg0, "echo"}])
    end)
  end

  test "signals return an exit code of 128 + signal" do
    # SIGTERM == 15
    assert {"", 128 + 15} ==
             Nerves.Port.cmd(test_path("fixtures/port/kill_self_with_signal.test"), [])
  end
end
