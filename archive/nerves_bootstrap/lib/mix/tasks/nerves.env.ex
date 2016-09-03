defmodule Mix.Tasks.Nerves.Env do
  use Mix.Task

  def run(_args) do
    Mix.Tasks.Deps.Compile.run ["nerves", "--include-children"]
    Mix.Task.reenable "deps.compile"
    Nerves.Env.start()
  end

end
