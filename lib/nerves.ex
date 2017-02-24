defmodule Nerves do
  def version,        do: unquote(Mix.Project.config[:version])
  def elixir_version, do: unquote(System.version)
end
