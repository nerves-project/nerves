defmodule Nerves.Release.Error do
  # TODO: Either apply this everywhere or change existing references
  @moduledoc """
  Error type for release errors
  """
  defexception [:message]
end
