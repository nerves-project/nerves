defmodule Mix.Nerves.FwupStream do
  @moduledoc """
  IO Stream for Fwup

  This functions the same as IO.Stream to push fwup IO to stdio, but
  it also captures the IO for cases where you want to check the
  output programatically as well.
  """

  defstruct device: :standard_io, line_or_bytes: :line, raw: true, output: ""

  def new(), do: %__MODULE__{}

  defimpl Collectable do
    def into(%{output: output} = stream) do
      {[output], collect(stream)}
    end

    defp collect(%{device: device, raw: raw} = stream) do
      fn
        acc, {:cont, x} ->
          case raw do
            true -> IO.binwrite(device, x)
            false -> IO.write(device, x)
          end

          [acc | x]

        acc, _ ->
          %{stream | output: IO.iodata_to_binary(acc)}
      end
    end
  end
end
