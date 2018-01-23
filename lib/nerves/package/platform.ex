defmodule Nerves.Package.Platform do
  @moduledoc """
  Defines the Nerves package platform behaviour
  """

  @callback bootstrap(Nerves.Package.t) ::
    :ok | {:error, error :: term}
  
  @callback build_path_link(package :: Nerves.Package.t) ::
    build_path_link :: String.t

  defmacro __using__(_) do
    quote do
      @behaviour Nerves.Artifact.Provider
      @behaviour Nerves.Package.Platform
    end
  end
end
