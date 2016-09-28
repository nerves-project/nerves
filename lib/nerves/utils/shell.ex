defmodule Nerves.Utils.Shell do

  def info(text, loc \\ "Nerves"),
    do: Mix.shell.info([IO.ANSI.yellow, "[#{loc}] #{text}", IO.ANSI.reset])

  def warn(text, loc \\ "Nerves"),
    do: Mix.shell.info([IO.ANSI.red, "[#{loc}] #{text}", IO.ANSI.reset])
end
