defmodule Nerves.Utils.Shell do
  @moduledoc false
  def warn(message) do
    Mix.shell().info([IO.ANSI.yellow(), message, IO.ANSI.reset()])
  end

  def error(message) do
    Mix.shell().info([IO.ANSI.red(), message, IO.ANSI.reset()])
  end

  def success(message) do
    Mix.shell().info([IO.ANSI.green(), message, IO.ANSI.reset()])
  end

  def info(message) do
    Mix.shell().info(message)
  end
end
