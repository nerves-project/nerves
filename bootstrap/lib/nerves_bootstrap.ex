defmodule Nerves.Bootstrap do
  @version Mix.Project.config[:version]
  def version, do: @version
end
