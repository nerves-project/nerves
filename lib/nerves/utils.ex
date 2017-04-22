defmodule Nerves.Utils do
  @alphanum 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_'

  def random_alpha_num(length) do
    :rand.seed(:exsplus, {1, 2, 3})
    Enum.take_random(@alphanum, length)
    |> to_string
  end

end
