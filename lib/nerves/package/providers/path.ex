defmodule Nerves.Package.Providers.Path do
  @behaviour Nerves.Package.Provider

  def artifact(_pkg, _toolchain) do
    # Verify the artifact is at the location passed
    :ok
  end
end
