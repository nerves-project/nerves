defmodule Nerves.Artifact.Provider do
  @moduledoc """
  Defines the Nerves package provider behaviour

  A package provider is a module that can take package source and produce
  artifacts.
  """

  @callback build(package :: Nerves.Package.t, toolchain :: atom, opts :: term) ::
    {:ok, build_path :: String.t} | {:error, reason :: term}

  @callback archive(package :: Nerves.Package.t, toolchain :: atom, opts :: term) ::
    {:ok, path :: String.t} | {:error, reason :: term}

  @callback clean(package :: Nerves.Package.t) ::
    :ok | {:error, reason :: term}

end
