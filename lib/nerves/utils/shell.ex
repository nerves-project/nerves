defmodule Nerves.Utils.Shell do
  @moduledoc false
  def warn(message) do
    Mix.shell().info([:yellow, message, :reset])
  end

  def error(message) do
    Mix.shell().info([:red, message, :reset])
  end

  def success(message) do
    Mix.shell().info([:green, message, :reset])
  end

  def info(message) do
    Mix.shell().info(message)
  end
end
