defmodule Mix.Nerves.Utils do

  def shell(cmd) do
    stream = IO.binstream(:standard_io, :line)
    Application.put_env(:porcelain, :driver, Porcelain.Driver.Basic)
    Application.ensure_started(:porcelain)
    Porcelain.shell(cmd, in: stream, async_in: true, out: stream, err: :out)
  end

end
