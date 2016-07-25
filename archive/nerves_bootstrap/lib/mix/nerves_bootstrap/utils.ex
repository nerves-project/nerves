defmodule Mix.Nerves.Bootstrap.Utils do

  def debug_info(msg) do
    if System.get_env("NERVES_DEBUG") == "1" do
      Mix.shell.info(msg)
    end
  end

end
