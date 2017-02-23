defmodule Nerves.Utils.Shell do

  def info(text, loc \\ "Nerves"),
    do: Mix.shell.info([IO.ANSI.light_white_background, IO.ANSI.black, "|#{loc}| #{text}", IO.ANSI.reset])

  def warn(text, loc \\ "Nerves"),
    do: Mix.shell.info([IO.ANSI.light_white_background, IO.ANSI.red, "|#{loc}| #{text}", IO.ANSI.reset])
end
