defmodule Nerves.Utils.Shell do
  @moduledoc false

  @spec warn(iodata()) :: :ok
  def warn(message) do
    Mix.shell().info([:yellow, message, :reset])
  end

  @spec error(iodata()) :: :ok
  def error(message) do
    Mix.shell().info([:red, message, :reset])
  end

  @spec success(iodata()) :: :ok
  def success(message) do
    Mix.shell().info([:green, message, :reset])
  end

  @spec info(iodata()) :: :ok
  def info(message) do
    Mix.shell().info(message)
  end
end
