defmodule GeneratedBehaviour do
  @callback run() :: atom()
end

defmodule GeneratedMacros do
  defmacro __using__(_opts) do
    quote do
      @behaviour GeneratedBehaviour
      def __generated__, do: :generated
    end
  end
end

defmodule GeneratedImpl do
  use GeneratedMacros

  def run, do: :ran
  def unused, do: :unused
end
