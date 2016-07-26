defmodule Nerves.Shell do
  def info(text, loc \\ "Nerves"),
    do: Mix.shell.info([IO.ANSI.yellow, "[#{loc}] #{text}", IO.ANSI.reset])
end
