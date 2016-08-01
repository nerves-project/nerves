defmodule Nerves.Package.Provider do
  @callback artifact(package :: Nerves.Package.t, toolchain :: atom) ::
    :ok | {:error, error :: term}

  @callback artifact(package :: Nerves.Package.t, toolchain :: atom) ::
    :ok | {:error, error :: term}

end
