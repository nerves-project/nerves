defmodule Nerves.Artifact.BuildRunners.Docker.Utils do
  @moduledoc false

  @doc false
  @spec shell_info(String.t(), String.t()) :: :ok
  def shell_info(header, text \\ "") do
    Mix.Nerves.IO.shell_info(header, text, Docker)
  end
end
