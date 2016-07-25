defmodule Nerves.Package.Providers.Local do
  use Nerves.Package.Provider

  def artifact(_pkg, _toolchain) do
    IO.inspect __MODULE__
  end
end
