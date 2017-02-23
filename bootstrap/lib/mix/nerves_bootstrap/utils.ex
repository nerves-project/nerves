defmodule Mix.Nerves.Bootstrap.Utils do

  def debug_info(header, text \\ "") do
    if System.get_env("NERVES_DEBUG") == "1" do
      shell_info(header)
      unless text == "" do
        Mix.shell.info(text)
      end
    end
  end

  def shell_info(text, loc \\ "Nerves Bootstrap"),
    do: Mix.shell.info([IO.ANSI.light_white_background, IO.ANSI.black, "|#{loc}| #{text}", IO.ANSI.reset])

  def shell_warn(text, loc \\ "Nerves Bootstrap"),
    do: Mix.shell.info([IO.ANSI.light_white_background, IO.ANSI.red, "|#{loc}| #{text}", IO.ANSI.reset])

end
