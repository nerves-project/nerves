defmodule Nerves.Artifact.BuildRunners.Docker.Utils do
  @moduledoc false
  def shell_info(header, text \\ "") do
    Mix.Nerves.IO.shell_info(header, text, Docker)
  end
end
