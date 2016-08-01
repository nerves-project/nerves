defmodule Nerves.Package.Platform do
  @callback bootstrap() ::
    :ok | {:error, error :: term}

end
