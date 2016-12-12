defmodule Nerves.Package.Platform do
  @moduledoc """
  Defines the Nerves package platform behaviour
  """

  @callback bootstrap() ::
    :ok | {:error, error :: term}

end
