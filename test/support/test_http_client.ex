# SPDX-FileCopyrightText: 2023 Jon Carstens
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule NervesTest.HTTPClient do
  @moduledoc """
  Test HTTPClient to use in tests

  Start this GenServer in your tests with a list of `:returns` which
  will be returned on each call until empty

  You can optionally provide `:echo` with a pid where the get/3
  call will be echoed to for verification
  """
  use GenServer

  @type opt :: {:name, GenServer.name()} | {:returns, [any()]} | {:echo, pid()}

  @spec start_link([opt()]) :: GenServer.on_start()
  def start_link(opts) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  defdelegate stop(pid), to: GenServer

  @spec get(pid(), String.t(), [any()]) :: :ok | any()
  def get(pid, url, opts), do: GenServer.call(pid, {:get, url, opts})

  @impl GenServer
  def init(opts) do
    {:ok, %{returns: opts[:returns] || [], echo: opts[:echo]}}
  end

  @impl GenServer
  def handle_call({:get, _url, _opts} = msg, _from, %{returns: []} = state) do
    if state.echo, do: send(state.echo, msg)
    {:reply, :ok, state}
  end

  def handle_call({:get, _url, _opts} = msg, _from, %{returns: [next | rem]} = state) do
    if state.echo, do: send(state.echo, msg)
    {:reply, next, %{state | returns: rem}}
  end
end
