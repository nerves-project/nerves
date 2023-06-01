defmodule Nerves.Utils do
  @moduledoc false
  @alphanum ~c"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_"

  if Application.compile_env(:nerves, :json_codec) do
    IO.warn(":json_codec is no longer supported. Please remove from your config", [])
  end

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
end
