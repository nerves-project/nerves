defmodule Nerves.Package.Provider do
  @moduledoc """
  Defines the Nerves package provider behaviour

  A package provider is a module that can take package source and produce
  artifacts.
  """

  @callback artifact(package :: Nerves.Package.t, toolchain :: atom, opts :: term) ::
    :ok | {:error, error :: term}

  # @callback shell(package :: Nerves.Package.t, opts :: term) ::
  #   :ok | {:error, error :: term}
  #
  # @callback clean(package :: Nerves.Package.t, opts :: term) ::
  #   :ok | {:error, error :: term}
  
end
