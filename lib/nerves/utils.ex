defmodule Nerves.Utils do
  @alphanum 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_'

  << i1 :: 32-unsigned-integer, i2 :: 32-unsigned-integer, i3 :: 32-unsigned-integer>> = :crypto.strong_rand_bytes(12)
  :rand.seed(:exsplus, {i1, i2, i3})

  def random_alpha_num(length) do
    Enum.take_random(@alphanum, length)
    |> to_string
  end

  def untar(file, destination \\ nil) do
    destination = destination || File.cwd!
    System.cmd("tar", ["xf", file, "--strip-components=1", "-C", destination])
  end
  
end
