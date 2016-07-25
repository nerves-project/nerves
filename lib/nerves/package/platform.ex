defmodule Nerves.Package.Platform do
  @callback bootstrap() ::
    :ok | {:error, error :: term}

  def __using__(_opts) do
    quote do
      @behaviour Nerves.Package.Platform
    end
  end

end
