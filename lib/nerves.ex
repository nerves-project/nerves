defmodule Nerves do
  @moduledoc false

  @spec version() :: String.t()
  def version(), do: Application.spec(:nerves)[:vsn] |> to_string()
end
