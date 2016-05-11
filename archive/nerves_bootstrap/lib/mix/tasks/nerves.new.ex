defmodule Mix.Tasks.Nerves.New do
  use Mix.Task
  import Mix.Generator

  @nerves Path.expand("../..", __DIR__)
  @version Mix.Project.config[:version]
  @shortdoc "Creates a new Nerves application"

  def run(_) do
    
  end

end
