defmodule Mix.Tasks.Compile.HostTool do
  use Mix.Task

  require Logger

  @moduledoc """
    Use a nerves host tool from an Elixir compiler
  """

  @shortdoc "Hello World File Generator"
  @recursive true

  def run(_args) do
    file =
      File.cwd!()
      |> Path.join("hello")

    case Nerves.Port.cmd("host_tool", [file]) do
      {_, 0} ->
        :ok

      {error, _} ->
        {:error, error}
    end
  end
end
