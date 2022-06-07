defmodule Nerves.Utils do
  @moduledoc false
  @alphanum 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_'

  @json_codec Jason

  <<i1::32-unsigned-integer, i2::32-unsigned-integer, i3::32-unsigned-integer>> =
    :crypto.strong_rand_bytes(12)

  :rand.seed(:exsplus, {i1, i2, i3})

  @spec random_alpha_num(non_neg_integer()) :: String.t()
  def random_alpha_num(length) do
    Enum.take_random(@alphanum, length)
    |> to_string
  end

  @spec untar(Path.t(), Path.t() | nil) :: {Collectable.t(), exit_status :: non_neg_integer()}
  def untar(file, destination \\ nil) do
    destination = destination || File.cwd!()
    Nerves.Port.cmd("tar", ["xf", file, "--strip-components=1", "-C", destination])
  end

  @spec json_decode(String.t()) :: map()
  def json_decode(data) do
    json_codec().decode!(data)
  end

  @spec json_encode(term) :: String.t()
  def json_encode(data) do
    json_codec().encode!(data)
  end

  defp json_codec() do
    json_codec = Application.get_env(:nerves, :json_codec) || @json_codec

    case Code.ensure_loaded?(json_codec) do
      true ->
        json_codec

      false ->
        Nerves.Utils.Shell.error("""
        Nerves is attempting to decode JSON data but there is no JSON codec defined.

        Please include :jason as a dependency or configure your own JSON parser
        by updating your config.exs

          config :nerves, json_codec: Poison
        """)
    end
  end
end
