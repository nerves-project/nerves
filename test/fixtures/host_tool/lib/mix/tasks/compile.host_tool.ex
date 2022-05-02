defmodule Mix.Tasks.Compile.HostTool do
  @shortdoc "Hello World File Generator"
  @moduledoc """
    Use a nerves host tool from an Elixir compiler
  """

  use Mix.Task

  require Logger

  @recursive true

  @impl Mix.Task
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
