defmodule Nerves.Package.Providers.Local do
  @behaviour Nerves.Package.Provider

  def artifact(_pkg, _toolchain, _opts) do
    IO.inspect __MODULE__
  end
end
