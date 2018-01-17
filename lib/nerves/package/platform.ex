defmodule Nerves.Package.Platform do
  @moduledoc """
  Defines the Nerves package platform behaviour
  """

  @callback bootstrap(Nerves.Package.t) ::
    :ok | {:error, error :: term}

  defmacro __using__(_) do
    quote do
      @behaviour Nerves.Artifact.Provider
      @behaviour Nerves.Package.Platform
    end
  end
end
