defmodule Mix.Tasks.Nerves.Clean do
  use Mix.Task

  def run(_argv) do
    Mix.Tasks.Nerves.Env.run([])
    Nerves.Env.clean()
  end

end
