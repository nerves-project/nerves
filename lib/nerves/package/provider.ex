defmodule Nerves.Package.Provider do
  @callback artifact(package :: Nerves.Package.t, toolchain :: atom, opts :: term) ::
    :ok | {:error, error :: term}

  # @callback shell(package :: Nerves.Package.t, opts :: term) ::
  #   :ok | {:error, error :: term}
  #
  # @callback clean(package :: Nerves.Package.t, opts :: term) ::
  #   :ok | {:error, error :: term}

end
