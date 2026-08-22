defmodule NervesNewOtp27.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        # Children for all targets
        # Starts a worker by calling: NervesNewOtp27.Worker.start_link(arg)
        # {NervesNewOtp27.Worker, arg},
      ] ++ children(target())

    opts = [strategy: :one_for_one, name: NervesNewOtp27.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # List all child processes to be supervised
  def children(:host) do
    [
      # Children that only run on the host
      # Starts a worker by calling: NervesNewOtp27.Worker.start_link(arg)
      # {NervesNewOtp27.Worker, arg},
    ]
  end

  def children(_target) do
    [
      # Children for all targets except host
      # Starts a worker by calling: NervesNewOtp27.Worker.start_link(arg)
      # {NervesNewOtp27.Worker, arg},
    ]
  end

  def target() do
    Application.get_env(:nerves_new_otp27, :target)
  end
end
