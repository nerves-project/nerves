defmodule Nerves.Host do
  @moduledoc """
  Entry point for a primitive host shell available through Erlang's job control mode.
  """

  alias Nerves.Host.Server

  @doc """
  This is the callback invoked by Erlang's shell when someone presses Ctrl+G and adds 's Elixir.Nerves.Host'.
  """
  def start(opts \\ [], mfa \\ {Nerves.Host, :dont_display_result, []}) do
    spawn(fn ->
      # The shell should not start until the system is up and running.
      case :init.notify_when_started(self()) do
        :started -> :ok
        _        -> :init.wait_until_started()
      end

      # Make sure the OTP app fires up since we came in through the shell's job control mode.
      {:ok, _} = Application.ensure_all_started(:nerves)
      :io.setopts(Process.group_leader, binary: true, encoding: :unicode)

      Server.start(opts, mfa)
    end)
  end

  def dont_display_result, do: "don't display result"
end

